#!/bin/bash
# Cleanup script for Oracle retry mechanism (Tokyo - proshanu)

DIR="$(dirname "$0")"
LOCK_FILE="${DIR}/.retry.lock"

echo "Terminating retry process if running..."
if [ -e "${LOCK_FILE}" ]; then
  PID=$(cat "${LOCK_FILE}")
  if kill -0 "$PID" 2>/dev/null; then
    kill "$PID"
    echo "Process $PID terminated."
  else
    echo "Process $PID not running."
  fi
  rm -f "${LOCK_FILE}"
else
  # Try to find it manually if lockfile is missing
  PIDS=$(pgrep -f "retry_oracle_instance.sh")
  if [ -n "$PIDS" ]; then
    kill $PIDS
    echo "Terminated fallback matching processes."
  else
    echo "No running retry processes found."
  fi
fi

echo "Removing script files..."
rm -f "${DIR}/retry_oracle_instance.sh"
rm -f "$0" # Remove self

echo "System cleanup complete. Logs are preserved at ${DIR}/retry.log (if they exist)."