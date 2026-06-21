#!/bin/bash
set -u

HOURS=24
OUTPUT_DIR=""

usage() {
  echo "Usage: icloud_sync_diagnostics.sh [--hours N] [--output DIR]"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --hours) HOURS="${2:-24}"; shift 2 ;;
    --output) OUTPUT_DIR="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done

case "$HOURS" in ''|*[!0-9]*) echo "--hours must be numeric" >&2; exit 2 ;; esac
[ "$(uname -s)" = "Darwin" ] || { echo "This tool must run on macOS." >&2; exit 1; }

STAMP="$(date +%Y%m%d_%H%M%S)"
OUTPUT_DIR="${OUTPUT_DIR:-./icloud-diagnostics-$STAMP}"
mkdir -p "$OUTPUT_DIR"
REPORT="$OUTPUT_DIR/icloud-report.txt"
CSV="$OUTPUT_DIR/components.csv"
JSON="$OUTPUT_DIR/summary.json"
ERRORS="$OUTPUT_DIR/command-errors.log"
: > "$REPORT"
: > "$ERRORS"
echo 'component,state,detail' > "$CSV"

section() {
  title="$1"
  shift
  {
    printf '\n===== %s =====\n' "$title"
    "$@"
  } >> "$REPORT" 2>> "$ERRORS" || true
}

redact() {
  sed -E 's/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/REDACTED_EMAIL/g'
}

record() {
  component="$1"
  state="$2"
  detail="$3"
  safe_detail=$(printf '%s' "$detail" | sed 's/"/""/g')
  printf '"%s","%s","%s"\n' "$component" "$state" "$safe_detail" >> "$CSV"
}

section "Collection metadata" /bin/bash -c 'date -u +%Y-%m-%dT%H:%M:%SZ; hostname; sw_vers; id'
section "iCloud-related processes" /bin/bash -c 'ps -Ao pid,user,etime,comm,args | grep -Ei "bird|cloudd|CloudDocs|accountsd|photolibraryd|photoanalysisd|sharedfilelistd" | grep -v grep || true'
section "CloudDocs status" /bin/bash -c 'brctl status 2>/dev/null | head -n 500 || true'
section "CloudDocs storage" /bin/bash -c 'du -sh "$HOME/Library/Mobile Documents" "$HOME/Library/Application Support/CloudDocs" 2>/dev/null || true; df -h "$HOME"'
section "Photos libraries" /bin/bash -c 'find "$HOME/Pictures" -maxdepth 2 -type d -name "*.photoslibrary" -print -exec du -sh {} \; 2>/dev/null || true'
section "Apple service DNS" /bin/bash -c 'for h in icloud.com www.icloud.com setup.icloud.com p34-cloudkit.com; do echo "--- $h"; dscacheutil -q host -a name "$h" 2>/dev/null | head -n 20; done'
section "Apple service HTTPS" /bin/bash -c 'for u in https://www.icloud.com https://setup.icloud.com; do echo "--- $u"; curl -I --connect-timeout 10 "$u" 2>/dev/null | head -n 10; done'

{
  printf '\n===== Recent iCloud and Photos events =====\n'
  /usr/bin/log show --last "${HOURS}h" --style compact --predicate '(process == "bird") OR (process == "cloudd") OR (process == "accountsd") OR (process == "photolibraryd") OR (process == "photoanalysisd") OR (subsystem CONTAINS[c] "CloudDocs") OR (eventMessage CONTAINS[c] "iCloud")' 2>/dev/null | tail -n 4000 | redact
} >> "$REPORT" 2>> "$ERRORS"

BIRD_RUNNING=false
pgrep -x bird >/dev/null 2>&1 && BIRD_RUNNING=true
CLOUDD_RUNNING=false
pgrep -x cloudd >/dev/null 2>&1 && CLOUDD_RUNNING=true
PHOTOS_RUNNING=false
pgrep -x photolibraryd >/dev/null 2>&1 && PHOTOS_RUNNING=true
MOBILE_DOCUMENTS_PRESENT=false
[ -d "$HOME/Library/Mobile Documents" ] && MOBILE_DOCUMENTS_PRESENT=true
APPLE_DNS_OK=false
dscacheutil -q host -a name icloud.com 2>/dev/null | grep -q 'ip_address' && APPLE_DNS_OK=true
APPLE_HTTPS_OK=false
curl -I --connect-timeout 10 https://www.icloud.com >/dev/null 2>&1 && APPLE_HTTPS_OK=true

record "bird process" "$BIRD_RUNNING" "iCloud Drive sync process"
record "cloudd process" "$CLOUDD_RUNNING" "CloudKit process"
record "Photos process" "$PHOTOS_RUNNING" "Photos library service"
record "Mobile Documents" "$MOBILE_DOCUMENTS_PRESENT" "$HOME/Library/Mobile Documents"
record "Apple DNS" "$APPLE_DNS_OK" "icloud.com"
record "Apple HTTPS" "$APPLE_HTTPS_OK" "https://www.icloud.com"

OVERALL="Healthy"
if ! $APPLE_DNS_OK || ! $APPLE_HTTPS_OK; then OVERALL="Attention required"; fi

cat > "$JSON" <<EOF
{
  "collected_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "hostname": "$(hostname)",
  "bird_running": $BIRD_RUNNING,
  "cloudd_running": $CLOUDD_RUNNING,
  "photos_service_running": $PHOTOS_RUNNING,
  "mobile_documents_present": $MOBILE_DOCUMENTS_PRESENT,
  "apple_dns_ok": $APPLE_DNS_OK,
  "apple_https_ok": $APPLE_HTTPS_OK,
  "overall_status": "$OVERALL"
}
EOF

printf '\niCloud diagnostics completed: %s\n' "$OUTPUT_DIR" | tee -a "$REPORT"
