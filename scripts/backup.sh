#!/usr/bin/env bash
# scripts/backup.sh — PostgreSQL + Redis backup with retention
set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-/opt/backups/devops-demo}"
RETENTION_DAYS="${RETENTION_DAYS:-7}"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

source "$(dirname "$0")/../.env" 2>/dev/null || true

mkdir -p "$BACKUP_DIR"/{postgres,redis}

echo "📦 Starting backup — $TIMESTAMP"

# ── PostgreSQL dump ───────────────────────────────────────────────────────────
PG_FILE="$BACKUP_DIR/postgres/pg_${TIMESTAMP}.sql.gz"
docker compose exec -T postgres \
  pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB" | gzip > "$PG_FILE"
echo "  ✅ PostgreSQL → $PG_FILE ($(du -sh "$PG_FILE" | cut -f1))"

# ── Redis RDB snapshot ────────────────────────────────────────────────────────
docker compose exec -T redis redis-cli -a "$REDIS_PASSWORD" BGSAVE
sleep 2   # wait for snapshot to complete
RDB_FILE="$BACKUP_DIR/redis/redis_${TIMESTAMP}.rdb"
docker compose cp redis:/data/dump.rdb "$RDB_FILE"
echo "  ✅ Redis RDB → $RDB_FILE"

# ── Prune old backups ─────────────────────────────────────────────────────────
find "$BACKUP_DIR" -type f -mtime +"$RETENTION_DAYS" -delete
echo "  🗑️  Pruned backups older than $RETENTION_DAYS days"

echo "✅ Backup complete"

# ── Optional: upload to S3 ────────────────────────────────────────────────────
# Uncomment and set AWS_S3_BUCKET env var to enable:
# if [[ -n "${AWS_S3_BUCKET:-}" ]]; then
#   aws s3 cp "$PG_FILE"  "s3://$AWS_S3_BUCKET/postgres/"
#   aws s3 cp "$RDB_FILE" "s3://$AWS_S3_BUCKET/redis/"
#   echo "  ☁️  Uploaded to S3: $AWS_S3_BUCKET"
# fi