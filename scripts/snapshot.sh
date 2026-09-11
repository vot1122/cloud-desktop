#!/usr/bin/env bash
# Mirrors /home/pc to the encrypted rclone remote defined by REMOTE.
# Uses --backup-dir so deletions are recoverable for 7 days, then pruned.
set -uo pipefail

REMOTE="${REMOTE:-crypt:home}"
STAMP="$(date -u +%Y%m%d-%H%M%S)"

# Important: rclone's config is written by the workflow step to ~/.config/rclone.
export RCLONE_CONFIG="${HOME}/.config/rclone/rclone.conf"

if [ ! -f "$RCLONE_CONFIG" ]; then
  echo "::warning::no rclone.conf found; skipping snapshot"
  exit 0
fi

echo "Snapshotting /home/pc -> ${REMOTE} (trash: ${STAMP})"

sudo chown -R "$(id -un)":"$(id -un)" /home/pc 2>/dev/null || true

rclone sync /home/pc "$REMOTE/" \
  --backup-dir "crypt:trash/${STAMP}" \
  --transfers 8 --checkers 8 \
  --stats 30s --stats-one-line \
  --exclude '.cache/**' \
  --exclude 'Cache/**' \
  --exclude '**/cache2/**' \
  --exclude '**/startupCache/**' \
  --exclude '**/shader-cache/**' \
  --exclude '.xsession-errors' \
  --exclude '.ICEauthority' \
  --exclude 'gvfs/**'

# Prune trash older than 7 days so the Drive doesn't fill up forever.
rclone delete --min-age 7d crypt:trash 2>/dev/null || true
rclone rmdirs crypt:trash --leave-root 2>/dev/null || true

echo "Snapshot complete."
