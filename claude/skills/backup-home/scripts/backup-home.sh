#!/bin/bash
set -e

# Configuration
BUCKET="win11-wsl-backups-690712292635-us-east-2-an"
PROFILE="minecraft-admin"
TARGET_PREFIX="DevEnv_Internal"
TIMESTAMP=$(date +"%Y-%m-%d_%H%M%S")
ARCHIVE_NAME="home_devenv_$TIMESTAMP.tar.gz"
TEMP_DIR="/tmp"
ARCHIVE_PATH="$TEMP_DIR/$ARCHIVE_NAME"

echo "=== Internal Home Backup ==="
echo "Target: s3://$BUCKET/$TARGET_PREFIX/$ARCHIVE_NAME"

# 1. Zip the home directory with critical exclusions
echo "[1/3] Archiving ~/ (excluding caches and container layers)..."
tar -czf "$ARCHIVE_PATH" \
    --exclude="$HOME/.cache" \
    --exclude="$HOME/.local/share/containers" \
    --exclude="$HOME/.npm" \
    --exclude="$HOME/.cargo/registry" \
    -C "$HOME/.." "$(basename "$HOME")"

ARCHIVE_SIZE=$(du -h "$ARCHIVE_PATH" | cut -f1)
echo "    Archive created: $ARCHIVE_SIZE"

# 2. Upload to S3
echo "[2/3] Uploading to S3..."
aws s3 cp "$ARCHIVE_PATH" "s3://$BUCKET/$TARGET_PREFIX/$ARCHIVE_NAME" --profile "$PROFILE"

# 3. Cleanup
echo "[3/3] Cleaning up local archive..."
rm "$ARCHIVE_PATH"

echo "=== Backup Complete ==="
