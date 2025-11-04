#!/bin/bash

set -e
set -o pipefail

# === Config ===
BackupDate=$(date +"%Y-%m-%d")
DOCKER_ROOT="/home/dev-project/docker"
LOCAL_BACKUP_DIR="/home/dev-project/backups/docker-backup"
REMOTE_USER="dev-project"
REMOTE_HOST="192.168.1.2"
REMOTE_PATH="/home/dev-project/backups/servarr"
BACKUP_FILE="$LOCAL_BACKUP_DIR/docker-servarr-$BackupDate.tar.gz"

# Docker services (tdarr excluded)
SERVICES=(
  bazarr huntarr jellyseerr lidarr prowlarr radarr sabnzbd
  flaresolverr jellyfin jelly-vue qbittorrent readarr sonarr
  code-server glance gpu-hot hometube profilarr
)

# === Logging ===
exec > >(tee -a /var/log/docker_backup.log) 2>&1
echo "=== Docker Backup Started at $(date) ==="

# Ensure backup dir
mkdir -p "$LOCAL_BACKUP_DIR"
chmod 700 "$LOCAL_BACKUP_DIR"

# === [1/6] Stop Containers ===
echo "=== [1/6] Stopping Docker containers (excluding tdarr) ==="
for SERVICE in "${SERVICES[@]}"; do
  SERVICE_DIR="$DOCKER_ROOT/$SERVICE"
  if [ -d "$SERVICE_DIR" ]; then
    echo "→ Stopping $SERVICE..."
    (cd "$SERVICE_DIR" && docker compose stop) || echo "⚠️  Failed to stop $SERVICE"
  else
    echo "⚠️  Skipping $SERVICE — directory not found."
  fi
done

# === [2/6] Create Backup ===
echo "=== [2/6] Creating backup archive (excluding tdarr) ==="
EXCLUDE_SIZE=$(du -sb --exclude="$DOCKER_ROOT/tdarr" "$DOCKER_ROOT" | awk '{print $1}')
tar --exclude='tdarr' -czf - -C "$DOCKER_ROOT" . \
  | pv -s "$EXCLUDE_SIZE" > "$BACKUP_FILE"
echo "✅ Backup created: $BACKUP_FILE"

# === [3/6] Restart NVIDIA & Docker ===
echo "=== [3/6] Restarting NVIDIA and Docker safely ==="

if systemctl is-active --quiet docker; then
  echo "→ Stopping Docker..."
  sudo systemctl stop docker
fi

echo "→ Restarting NVIDIA stack..."
sudo systemctl stop nvidia-persistenced || true
sudo modprobe -r nvidia_uvm nvidia_drm nvidia_modeset nvidia || true
sudo modprobe nvidia || true
sudo systemctl start nvidia-persistenced

echo "→ Starting Docker..."
sudo systemctl start docker

# Wait for Docker
echo "Waiting for Docker to become ready..."
for i in {1..10}; do
  if docker info >/dev/null 2>&1; then
    echo "✅ Docker is ready."
    break
  fi
  echo "⏳ Waiting for Docker... ($i/10)"
  sleep 3
done

# === [4/6] Restart Containers ===
echo "=== [4/6] Starting Docker containers (excluding tdarr) ==="
for SERVICE in "${SERVICES[@]}"; do
  SERVICE_DIR="$DOCKER_ROOT/$SERVICE"
  if [ -d "$SERVICE_DIR" ] && [ -f "$SERVICE_DIR/docker-compose.yml" ]; then
    echo "→ Starting $SERVICE..."
    (cd "$SERVICE_DIR" && docker compose up -d) \
      && echo "✅ $SERVICE started." \
      || echo "❌ Failed to start $SERVICE"
  else
    echo "⚠️  Skipping $SERVICE — missing directory or compose file."
  fi
done

# === [5/6] Transfer Backup ===
echo "=== [5/6] Transferring backup to remote server ==="
if scp -v -C -o ConnectTimeout=30 -o StrictHostKeyChecking=no \
  "$BACKUP_FILE" "$REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH/"; then
  echo "✅ Remote transfer completed successfully!"
else
  echo "❌ Remote transfer failed!"
  exit 1
fi

# === [6/6] Retention Policy ===
echo "🧹 Cleaning up old local backups (keeping last 3)..."
cd "$LOCAL_BACKUP_DIR"
LC_ALL=C ls -tp docker-servarr-*.tar.gz | grep -v '/$' | tail -n +4 | xargs -r rm --
echo "✅ Backup rotation completed."

echo "🎉 All done! Backup stored locally and remotely."
echo "=== Script Finished at $(date) ==="
