#!/usr/bin/env bash
# Runs the live desktop session for SESSION_MINUTES, taking an encrypted
# snapshot to rclone every SNAPSHOT_EVERY_MIN minutes. Exits cleanly so the
# workflow's "Trigger next session" step can chain the next runner.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SESSION_MINUTES="${SESSION_MINUTES:-330}"
SNAPSHOT_EVERY_MIN="${SNAPSHOT_EVERY_MIN:-30}"

start=$(date +%s)
echo "::notice::Session started. Will run for ${SESSION_MINUTES}m, snapshot every ${SNAPSHOT_EVERY_MIN}m."

while true; do
  now=$(date +%s)
  elapsed=$(( (now - start) / 60 ))
  if [ "$elapsed" -ge "$SESSION_MINUTES" ]; then
    echo "Session time budget reached after ${elapsed}m."
    break
  fi
  sleep $(( SNAPSHOT_EVERY_MIN * 60 ))
  echo "[$(date -u +%FT%TZ)] Periodic checkpoint..."
  bash "$SCRIPT_DIR/snapshot.sh" || echo "::warning::periodic snapshot failed, session continues"
done

echo "Session loop complete."
