#!/usr/bin/env bash
# Runs the live desktop session for SESSION_MINUTES, taking an encrypted
# snapshot to rclone every SNAPSHOT_EVERY_MIN minutes. Monitors xrdp and
# restarts it if it dies. Exits cleanly so the workflow's "Trigger next
# session" step can chain the next runner.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SESSION_MINUTES="${SESSION_MINUTES:-330}"
SNAPSHOT_EVERY_MIN="${SNAPSHOT_EVERY_MIN:-30}"

xrdp_healthy() {
  ss -ltn 2>/dev/null | grep -q ':3389 '
}

restart_xrdp() {
  echo "[$(date -u +%FT%TZ)] ::warning:: xrdp is down — restarting"
  sudo service xrdp restart 2>/dev/null || sudo systemctl restart xrdp 2>/dev/null || true
}

start=$(date +%s)
echo "::notice::Session started $(date -u +%FT%TZ). Running for ${SESSION_MINUTES}m, snapshot every ${SNAPSHOT_EVERY_MIN}m."

while true; do
  now=$(date +%s)
  elapsed=$(( (now - start) / 60 ))
  remaining=$(( SESSION_MINUTES - elapsed ))
  if [ "$remaining" -le 0 ]; then
    echo "Session time budget reached after ${elapsed}m."
    break
  fi
  # Never sleep past the session end — clamp the sleep to remaining time.
  sleep_secs=$(( SNAPSHOT_EVERY_MIN * 60 ))
  max_secs=$(( remaining * 60 ))
  [ "$sleep_secs" -gt "$max_secs" ] && sleep_secs="$max_secs"
  sleep "$sleep_secs"
  # Health: keep xrdp alive during the session.
  if ! xrdp_healthy; then restart_xrdp; fi
  echo "[$(date -u +%FT%TZ)] Periodic checkpoint (elapsed ${elapsed}m)..."
  bash "$SCRIPT_DIR/snapshot.sh" || echo "::warning:: periodic snapshot failed, session continues"
done

echo "[$(date -u +%FT%TZ)] Session loop complete."
