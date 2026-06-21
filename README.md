# macOS Apple Account and iCloud Sync Diagnostics

This toolkit diagnoses Apple Account, iCloud Drive, CloudDocs and Photos sync problems and includes a service-repair workflow.

## Diagnostic usage

```bash
chmod +x src/icloud_sync_diagnostics.sh
./src/icloud_sync_diagnostics.sh --hours 24
```

## Repair usage

Preview the repair:

```bash
chmod +x src/icloud_sync_repair.sh
./src/icloud_sync_repair.sh --repair --dry-run
```

Apply the repair:

```bash
./src/icloud_sync_repair.sh --repair
```

Run without prompts:

```bash
./src/icloud_sync_repair.sh --repair --yes
```

## Repair behaviour

- Restarts the Apple account and iCloud sync processes used by iCloud Drive and Photos.
- Restarts Finder to refresh iCloud Drive integration.
- Rechecks Apple DNS and HTTPS connectivity.
- Rechecks the iCloud data folder and sync processes after repair.
- Supports confirmation, dry-run, logs and clear exit codes.

The repair does not sign users out, remove cloud files, remove Photos libraries or change Apple Account settings. Account restrictions, storage limits and provider-side outages can still require manual intervention.

## Privacy

Reports avoid authentication tokens and redact obvious email addresses. Review reports before sharing because they can contain local paths and device information.

## Requirements

- macOS 12 or later recommended
- Bash 3.2+

## Author

Dewald Pretorius — L2 IT Support Engineer
