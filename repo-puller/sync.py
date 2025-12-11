#!/usr/bin/env python3
"""
Repo Puller - Synchronize code from reference repo to target repo without mistakes
"""
import os
import sys
import sqlite3
import shutil
import hashlib
import argparse
from datetime import datetime
from pathlib import Path
from typing import List, Tuple, Optional

DB_PATH = Path(__file__).parent / "repo_puller.db"

class RepoPuller:
    def __init__(self, db_path: Path = DB_PATH):
        self.db_path = db_path
        self.conn = None
        self.init_db()
    
    def init_db(self):
        """Initialize database with schema"""
        self.conn = sqlite3.connect(self.db_path)
        schema_path = Path(__file__).parent / "schema.sql"
        with open(schema_path, 'r') as f:
            self.conn.executescript(f.read())
        self.conn.commit()
    
    def get_file_hash(self, file_path: Path) -> str:
        """Calculate SHA256 hash of file"""
        sha256 = hashlib.sha256()
        with open(file_path, 'rb') as f:
            for chunk in iter(lambda: f.read(4096), b''):
                sha256.update(chunk)
        return sha256.hexdigest()
    
    def create_backup(self, target_repo: Path, sync_op_id: int) -> Path:
        """Create timestamped backup of target repo"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        backup_path = target_repo.parent / f"{target_repo.name}_backup_{timestamp}"
        
        print(f"Creating backup: {backup_path}")
        shutil.copytree(target_repo, backup_path, symlinks=True)
        
        # Calculate backup stats
        file_count = sum(1 for _ in backup_path.rglob('*') if _.is_file())
        size_bytes = sum(f.stat().st_size for f in backup_path.rglob('*') if f.is_file())
        
        # Record backup in database
        self.conn.execute("""
            INSERT INTO backups (sync_operation_id, backup_path, created_at, size_bytes, file_count)
            VALUES (?, ?, ?, ?, ?)
        """, (sync_op_id, str(backup_path), datetime.now().isoformat(), size_bytes, file_count))
        self.conn.commit()
        
        return backup_path
    
    def get_files_to_sync(self, source_repo: Path, target_repo: Path) -> List[Tuple[Path, Path]]:
        """Get list of files that need to be synced from source to target"""
        files_to_sync = []
        
        # Focus on src directory
        source_src = source_repo / "src"
        target_src = target_repo / "src"
        
        if not source_src.exists():
            print(f"Warning: {source_src} does not exist")
            return files_to_sync
        
        # Get all files in source/src
        for source_file in source_src.rglob('*'):
            if source_file.is_file():
                # Calculate relative path
                rel_path = source_file.relative_to(source_src)
                target_file = target_src / rel_path
                
                # Check if file needs to be copied
                needs_copy = False
                if not target_file.exists():
                    needs_copy = True
                    print(f"  NEW: {rel_path}")
                else:
                    source_hash = self.get_file_hash(source_file)
                    target_hash = self.get_file_hash(target_file)
                    if source_hash != target_hash:
                        needs_copy = True
                        print(f"  DIFF: {rel_path}")
                
                if needs_copy:
                    files_to_sync.append((source_file, target_file))
        
        return files_to_sync
    
    def sync_repos(self, source_repo: Path, target_repo: Path, dry_run: bool = False) -> int:
        """Sync files from source to target repo"""
        print(f"\n{'='*80}")
        print(f"Repo Puller - Sync Operation")
        print(f"{'='*80}")
        print(f"Source: {source_repo}")
        print(f"Target: {target_repo}")
        print(f"Dry Run: {dry_run}")
        print(f"{'='*80}\n")
        
        # Validate repos exist
        if not source_repo.exists():
            print(f"ERROR: Source repo does not exist: {source_repo}")
            return 1
        if not target_repo.exists():
            print(f"ERROR: Target repo does not exist: {target_repo}")
            return 1
        
        # Create sync operation record
        cursor = self.conn.execute("""
            INSERT INTO sync_operations 
            (timestamp, source_repo, target_repo, backup_path, status, dry_run)
            VALUES (?, ?, ?, ?, ?, ?)
        """, (datetime.now().isoformat(), str(source_repo), str(target_repo), '', 'in_progress', 1 if dry_run else 0))
        sync_op_id = cursor.lastrowid
        self.conn.commit()
        
        try:
            # Create backup (unless dry run)
            backup_path = None
            if not dry_run:
                backup_path = self.create_backup(target_repo, sync_op_id)
                self.conn.execute("UPDATE sync_operations SET backup_path = ? WHERE id = ?",
                                (str(backup_path), sync_op_id))
                self.conn.commit()

            # Get files to sync
            print("\nAnalyzing files to sync...")
            files_to_sync = self.get_files_to_sync(source_repo, target_repo)

            if not files_to_sync:
                print("\n✅ No files need to be synced - repos are already in sync!")
                self.conn.execute("UPDATE sync_operations SET status = 'completed' WHERE id = ?", (sync_op_id,))
                self.conn.commit()
                return 0

            print(f"\nFound {len(files_to_sync)} files to sync")

            if dry_run:
                print("\n🔍 DRY RUN - No files will be copied")
                for source_file, target_file in files_to_sync:
                    rel_path = source_file.relative_to(source_repo / "src")
                    print(f"  Would copy: {rel_path}")
                self.conn.execute("UPDATE sync_operations SET status = 'completed', files_copied = 0, files_skipped = ? WHERE id = ?",
                                (len(files_to_sync), sync_op_id))
                self.conn.commit()
                return 0

            # Copy files
            print("\n📋 Copying files...")
            files_copied = 0
            files_failed = 0

            for source_file, target_file in files_to_sync:
                rel_path = source_file.relative_to(source_repo / "src")
                try:
                    # Get hashes
                    source_hash = self.get_file_hash(source_file)
                    target_hash_before = self.get_file_hash(target_file) if target_file.exists() else None

                    # Create parent directory if needed
                    target_file.parent.mkdir(parents=True, exist_ok=True)

                    # Copy file
                    shutil.copy2(source_file, target_file)
                    target_hash_after = self.get_file_hash(target_file)

                    # Verify copy
                    if source_hash != target_hash_after:
                        raise Exception(f"Hash mismatch after copy: {source_hash} != {target_hash_after}")

                    print(f"  ✅ {rel_path}")
                    files_copied += 1

                    # Record in database
                    self.conn.execute("""
                        INSERT INTO file_changes
                        (sync_operation_id, file_path, action, source_hash, target_hash_before, target_hash_after, file_size, timestamp)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    """, (sync_op_id, str(rel_path), 'copied', source_hash, target_hash_before, target_hash_after,
                          source_file.stat().st_size, datetime.now().isoformat()))

                except Exception as e:
                    print(f"  ❌ {rel_path}: {e}")
                    files_failed += 1

                    # Record failure in database
                    self.conn.execute("""
                        INSERT INTO file_changes
                        (sync_operation_id, file_path, action, error_message, timestamp)
                        VALUES (?, ?, ?, ?, ?)
                    """, (sync_op_id, str(rel_path), 'failed', str(e), datetime.now().isoformat()))

            self.conn.commit()

            # Update sync operation status
            status = 'completed' if files_failed == 0 else 'failed'
            self.conn.execute("""
                UPDATE sync_operations
                SET status = ?, files_copied = ?, files_failed = ?
                WHERE id = ?
            """, (status, files_copied, files_failed, sync_op_id))
            self.conn.commit()

            # Print summary
            print(f"\n{'='*80}")
            print(f"Sync Summary")
            print(f"{'='*80}")
            print(f"Files copied: {files_copied}")
            print(f"Files failed: {files_failed}")
            if backup_path:
                print(f"Backup location: {backup_path}")
            print(f"{'='*80}\n")

            return 0 if files_failed == 0 else 1

        except Exception as e:
            print(f"\n❌ ERROR: {e}")
            self.conn.execute("UPDATE sync_operations SET status = 'failed', error_message = ? WHERE id = ?",
                            (str(e), sync_op_id))
            self.conn.commit()
            return 1

    def show_status(self):
        """Show status of recent sync operations"""
        print(f"\n{'='*80}")
        print("Recent Sync Operations")
        print(f"{'='*80}\n")

        cursor = self.conn.execute("""
            SELECT id, timestamp, source_repo, target_repo, status, files_copied, files_failed, backup_path
            FROM sync_operations
            ORDER BY timestamp DESC
            LIMIT 10
        """)

        for row in cursor:
            sync_id, timestamp, source, target, status, copied, failed, backup = row
            print(f"ID: {sync_id}")
            print(f"  Timestamp: {timestamp}")
            print(f"  Source: {source}")
            print(f"  Target: {target}")
            print(f"  Status: {status}")
            print(f"  Files copied: {copied}")
            print(f"  Files failed: {failed}")
            if backup:
                print(f"  Backup: {backup}")
            print()

    def rollback(self, sync_op_id: Optional[int] = None):
        """Rollback to a previous backup"""
        if sync_op_id is None:
            # Get most recent completed sync
            cursor = self.conn.execute("""
                SELECT id FROM sync_operations
                WHERE status = 'completed' AND backup_path != ''
                ORDER BY timestamp DESC LIMIT 1
            """)
            row = cursor.fetchone()
            if not row:
                print("No sync operations found to rollback")
                return 1
            sync_op_id = row[0]

        # Get backup info
        cursor = self.conn.execute("""
            SELECT backup_path, target_repo FROM sync_operations WHERE id = ?
        """, (sync_op_id,))
        row = cursor.fetchone()
        if not row:
            print(f"Sync operation {sync_op_id} not found")
            return 1

        backup_path, target_repo = row
        backup_path = Path(backup_path)
        target_repo = Path(target_repo)

        if not backup_path.exists():
            print(f"Backup not found: {backup_path}")
            return 1

        print(f"Rolling back sync operation {sync_op_id}")
        print(f"  Backup: {backup_path}")
        print(f"  Target: {target_repo}")

        # Remove current target
        if target_repo.exists():
            print(f"  Removing current target...")
            shutil.rmtree(target_repo)

        # Restore from backup
        print(f"  Restoring from backup...")
        shutil.copytree(backup_path, target_repo, symlinks=True)

        # Update database
        self.conn.execute("UPDATE sync_operations SET status = 'rolled_back' WHERE id = ?", (sync_op_id,))
        self.conn.commit()

        print(f"✅ Rollback complete")
        return 0

    def close(self):
        if self.conn:
            self.conn.close()


def main():
    parser = argparse.ArgumentParser(description="Repo Puller - Sync repos without mistakes")
    parser.add_argument('--source', type=str, help='Source repository path')
    parser.add_argument('--target', type=str, help='Target repository path')
    parser.add_argument('--dry-run', action='store_true', help='Show what would be done without making changes')
    parser.add_argument('--status', action='store_true', help='Show status of recent sync operations')
    parser.add_argument('--rollback', action='store_true', help='Rollback most recent sync')
    parser.add_argument('--rollback-id', type=int, help='Rollback specific sync operation by ID')

    args = parser.parse_args()

    puller = RepoPuller()

    try:
        if args.status:
            puller.show_status()
            return 0

        if args.rollback or args.rollback_id:
            return puller.rollback(args.rollback_id)

        if not args.source or not args.target:
            parser.print_help()
            return 1

        source_repo = Path(args.source).expanduser().resolve()
        target_repo = Path(args.target).expanduser().resolve()

        return puller.sync_repos(source_repo, target_repo, dry_run=args.dry_run)

    finally:
        puller.close()


if __name__ == '__main__':
    sys.exit(main())

