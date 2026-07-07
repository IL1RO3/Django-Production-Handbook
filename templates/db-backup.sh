#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

APP_NAME="<APP_NAME>"
DATABASE="<DB_NAME>"
BACKUP_DIR="/var/backups/${APP_NAME}/postgresql"
KEEP_DAYS=14

install -d -m 700 -o postgres -g postgres "$BACKUP_DIR"
timestamp="$(date -u +%Y-%m-%dT%H%M%SZ)"
tmp_file="${BACKUP_DIR}/.${APP_NAME}-${timestamp}.tmp"
final_file="${BACKUP_DIR}/${APP_NAME}-${timestamp}.dump"

cleanup() { rm -f "$tmp_file"; }
trap cleanup EXIT

pg_dump --format=custom --no-owner --no-privileges --file="$tmp_file" "$DATABASE"
pg_restore --list "$tmp_file" > /dev/null
mv "$tmp_file" "$final_file"
trap - EXIT

find "$BACKUP_DIR" -type f -name "${APP_NAME}-*.dump" -mtime +"$KEEP_DAYS" -delete
printf 'Backup created: %s\n' "$final_file"
