#!/bin/bash
set -u

DO_REPAIR=false
ASSUME_YES=false
DRY_RUN=false
OUTPUT_DIR=""

usage() {
  cat <<'EOF'
Usage: icloud_sync_repair.sh [--repair] [--dry-run] [--yes] [--output DIR]

Default mode performs verification only.
--repair   Restart Apple account and iCloud sync services, then verify.
--dry-run  Show the repair actions without changing the Mac.
--yes      Skip confirmation prompts.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repair) DO_REPAIR=true; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    --yes) ASSUME_YES=true; shift ;;
    --output) OUTPUT_DIR="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done

[ "$(uname -s)" = "Darwin" ] || { echo "This tool must run on macOS." >&2; exit 1; }

STAMP="$(date +%Y%m%d_%H%M%S)"
OUTPUT_DIR="${OUTPUT_DIR:-./icloud-repair-$STAMP}"
mkdir -p "$OUTPUT_DIR"
LOG="$OUTPUT_DIR/repair.log"
VERIFY="$OUTPUT_DIR/verification.txt"
: > "$LOG"
: > "$VERIFY"

log() {
  printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG"
}

confirm() {
  $ASSUME_YES && return 0
  printf '%s [y/N]: ' "$1"
  read -r answer
  case "$answer" in y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
}

run_action() {
  description="$1"
  shift
  log "$description"
  if $DRY_RUN; then
    printf 'DRY-RUN:' >> "$LOG"
    printf ' %q' "$@" >> "$LOG"
    printf '\n' >> "$LOG"
    return 0
  fi
  "$@" >> "$LOG" 2>&1 || return $?
}

verify_state() {
  {
    echo "Collected: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "Host: $(hostname)"
    echo
    echo "Processes:"
    ps -Ao pid,user,etime,comm,args | grep -Ei 'bird|cloudd|accountsd|photolibraryd|photoanalysisd|sharedfilelistd' | grep -v grep || true
    echo
    echo "Mobile Documents:"
    [ -d "$HOME/Library/Mobile Documents" ] && ls -ld "$HOME/Library/Mobile Documents" || echo "Not present"
    echo
    echo "Apple service tests:"
    dscacheutil -q host -a name icloud.com 2>/dev/null | head -n 20 || true
    curl -I --connect-timeout 10 https://www.icloud.com 2>/dev/null | head -n 10 || true
    echo
    echo "CloudDocs status:"
    brctl status 2>/dev/null | head -n 200 || true
  } > "$VERIFY" 2>&1
}

verify_state

if ! $DO_REPAIR; then
  log "Verification-only mode completed. Use --repair to apply safe service restarts."
  exit 0
fi

if ! confirm "Restart Apple account and iCloud sync services?"; then
  log "Repair cancelled by user."
  exit 0
fi

run_action "Restarting accountsd" /usr/bin/killall accountsd || true
run_action "Restarting bird" /usr/bin/killall bird || true
run_action "Restarting cloudd" /usr/bin/killall cloudd || true
run_action "Restarting sharedfilelistd" /usr/bin/killall sharedfilelistd || true
run_action "Restarting photolibraryd" /usr/bin/killall photolibraryd || true
run_action "Restarting photoanalysisd" /usr/bin/killall photoanalysisd || true
run_action "Restarting Finder to refresh iCloud integration" /usr/bin/killall Finder || true

if ! $DRY_RUN; then
  sleep 5
fi

verify_state

APPLE_DNS_OK=false
dscacheutil -q host -a name icloud.com 2>/dev/null | grep -q 'ip_address' && APPLE_DNS_OK=true
APPLE_HTTPS_OK=false
curl -I --connect-timeout 10 https://www.icloud.com >/dev/null 2>&1 && APPLE_HTTPS_OK=true
BIRD_RUNNING=false
pgrep -x bird >/dev/null 2>&1 && BIRD_RUNNING=true

if $APPLE_DNS_OK && $APPLE_HTTPS_OK && $BIRD_RUNNING; then
  log "Repair verification passed."
  exit 0
fi

log "Repair completed, but one or more verification checks still require attention."
exit 1
