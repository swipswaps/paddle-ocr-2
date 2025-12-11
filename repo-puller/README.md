# Repo Puller

Automated tool to synchronize code from a reference repository (receipts-ocr) to a target repository (paddle-ocr) without mistakes.

## Features

- Backs up target repository before making changes
- Tracks all file differences in SQLite database
- Copies files systematically from source to target
- Logs all operations for audit trail
- Can rollback changes if needed

## Usage

```bash
# Initialize and run sync
python3 sync.py --source ~/Documents/receipts-ocr --target ~/Documents/paddle-ocr

# Dry run (show what would be copied without making changes)
python3 sync.py --source ~/Documents/receipts-ocr --target ~/Documents/paddle-ocr --dry-run

# Rollback to previous backup
python3 sync.py --rollback

# Show status
python3 sync.py --status
```

## Database Schema

- `sync_operations` - Tracks each sync operation
- `file_changes` - Tracks each file copied/modified
- `backups` - Tracks backup locations

