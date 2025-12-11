-- Repo Puller Database Schema

CREATE TABLE IF NOT EXISTS sync_operations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TEXT NOT NULL,
    source_repo TEXT NOT NULL,
    target_repo TEXT NOT NULL,
    backup_path TEXT NOT NULL,
    status TEXT NOT NULL, -- 'in_progress', 'completed', 'failed', 'rolled_back'
    files_copied INTEGER DEFAULT 0,
    files_skipped INTEGER DEFAULT 0,
    files_failed INTEGER DEFAULT 0,
    error_message TEXT,
    dry_run INTEGER DEFAULT 0
);

CREATE TABLE IF NOT EXISTS file_changes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    sync_operation_id INTEGER NOT NULL,
    file_path TEXT NOT NULL,
    action TEXT NOT NULL, -- 'copied', 'skipped', 'failed'
    source_hash TEXT,
    target_hash_before TEXT,
    target_hash_after TEXT,
    file_size INTEGER,
    error_message TEXT,
    timestamp TEXT NOT NULL,
    FOREIGN KEY (sync_operation_id) REFERENCES sync_operations(id)
);

CREATE TABLE IF NOT EXISTS backups (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    sync_operation_id INTEGER NOT NULL,
    backup_path TEXT NOT NULL,
    created_at TEXT NOT NULL,
    size_bytes INTEGER,
    file_count INTEGER,
    FOREIGN KEY (sync_operation_id) REFERENCES sync_operations(id)
);

CREATE INDEX IF NOT EXISTS idx_sync_operations_timestamp ON sync_operations(timestamp);
CREATE INDEX IF NOT EXISTS idx_file_changes_sync_op ON file_changes(sync_operation_id);
CREATE INDEX IF NOT EXISTS idx_file_changes_file_path ON file_changes(file_path);
CREATE INDEX IF NOT EXISTS idx_backups_sync_op ON backups(sync_operation_id);

