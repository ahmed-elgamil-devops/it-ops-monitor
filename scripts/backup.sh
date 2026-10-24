#!/usr/bin/env bash
# Nightly backup of the monitor config and Grafana data.
# Keeps the last 7 local copies and (optionally) uploads an off-site copy to
# AWS S3 or Azure Blob Storage (3-2-1 backup rule).
set -euo pipefail

APP_DIR="${APP_DIR:-/opt/it-ops-monitor}"
BACKUP_DIR="${BACKUP_DIR:-/var/backups/it-ops-monitor}"
KEEP="${KEEP:-7}"
S3_BUCKET="${S3_BUCKET:-}"          # e.g. s3://my-company-backups (empty = skip)
AZ_ACCOUNT="${AZ_ACCOUNT:-}"        # Azure storage account name (empty = skip)
AZ_CONTAINER="${AZ_CONTAINER:-backups}"

mkdir -p "$BACKUP_DIR"
stamp="$(date +%Y-%m-%d_%H%M)"
file="$BACKUP_DIR/it-ops-monitor_$stamp.tar.gz"

# config files + Grafana dashboards/users (docker volume)
grafana_vol="$(docker volume inspect -f '{{ .Mountpoint }}' it-ops-monitor_grafana-data 2>/dev/null || true)"
tar -czf "$file" -C "$APP_DIR" app/targets.yml monitoring docker-compose.yml \
  ${grafana_vol:+-C "$grafana_vol" .}

echo "$(date '+%F %T') created $file ($(du -h "$file" | cut -f1))"

# rotation: keep only the newest $KEEP backups
find "$BACKUP_DIR" -name 'it-ops-monitor_*.tar.gz' -printf '%T@ %p\n' | sort -rn \
  | tail -n +$((KEEP + 1)) | cut -d' ' -f2- | xargs -r rm -f

if [[ -n "$S3_BUCKET" ]]; then
  aws s3 cp "$file" "$S3_BUCKET/" --only-show-errors
  echo "$(date '+%F %T') uploaded to $S3_BUCKET"
fi

if [[ -n "$AZ_ACCOUNT" ]]; then
  az storage blob upload --auth-mode login --account-name "$AZ_ACCOUNT" \
    --container-name "$AZ_CONTAINER" --file "$file" --name "$(basename "$file")" --only-show-errors
  echo "$(date '+%F %T') uploaded to Azure Blob $AZ_ACCOUNT/$AZ_CONTAINER"
fi
