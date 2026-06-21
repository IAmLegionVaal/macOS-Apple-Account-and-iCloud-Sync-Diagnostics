# macOS Apple Account and iCloud Sync Diagnostics

A read-only Bash toolkit for collecting Apple Account, iCloud Drive, CloudDocs, Photos, storage, process, and recent sync-event evidence.

## Usage

```bash
chmod +x src/icloud_sync_diagnostics.sh
./src/icloud_sync_diagnostics.sh --hours 24
```

## Checks performed

- Apple Account and iCloud service indicators without displaying passwords or tokens
- iCloud Drive and CloudDocs process state
- CloudDocs and Mobile Documents storage usage
- Photos library and photo-analysis process indicators
- Network and DNS reachability to Apple service domains
- Recent CloudDocs, bird, cloudd, account, and Photos sync events
- Text, CSV, and JSON reports

## Privacy

The script avoids printing authentication tokens and redacts obvious email addresses from logs. Reports can still contain usernames, file paths, and device information and should be reviewed before sharing.

## Safety

The toolkit does not sign users in or out, reset iCloud, delete caches, change account settings, force uploads, or modify Photos libraries.

## Requirements

- macOS 12 or later recommended
- Bash 3.2+

## Author

Dewald Pretorius — L2 IT Support Engineer
