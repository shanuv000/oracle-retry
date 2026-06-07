#!/bin/bash
# Oracle Always Free Instance Auto-Retry Script (Tokyo - proshanu)
# Features: 30-sec retry, log rotation, Discord notification, reboot-safe

DIR="$(dirname "$0")"
LOG_FILE="${DIR}/retry.log"
LOCK_FILE="${DIR}/.retry.lock"
PID_FILE="${DIR}/retry.pid"
MAX_LOG_SIZE_MB=10

# Load environment variables securely
if [ -f "${DIR}/.env" ]; then
  source "${DIR}/.env"
else
  echo "Error: .env file not found. Please create one containing DISCORD_WEBHOOK=\"your_url_here\""
  exit 1
fi

if [ -z "$DISCORD_WEBHOOK" ]; then
  echo "Error: DISCORD_WEBHOOK is not set in .env"
  exit 1
fi

# Avoid spawning duplicate processes
if [ -e "${LOCK_FILE}" ] && kill -0 $(cat "${LOCK_FILE}") 2>/dev/null; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Script is already running. Exiting." >> "${LOG_FILE}"
  exit 1
fi

# Set lock
echo $$ > "${LOCK_FILE}"
echo $$ > "${PID_FILE}"

# Ensure lock is removed on exit
trap "rm -f ${LOCK_FILE}; exit" INT TERM EXIT

# Log rotation function
rotate_log() {
  if [ -f "${LOG_FILE}" ]; then
    local size_kb=$(du -k "${LOG_FILE}" | cut -f1)
    local max_kb=$((MAX_LOG_SIZE_MB * 1024))
    if [ "$size_kb" -gt "$max_kb" ]; then
      mv "${LOG_FILE}" "${LOG_FILE}.old"
      echo "$(date '+%Y-%m-%d %H:%M:%S') - Log rotated (previous log saved as retry.log.old)" > "${LOG_FILE}"
    fi
  fi
}

# Discord notification function
send_discord() {
  local message="$1"
  local payload=$(cat <<EOF
{
  "content": "${message}",
  "username": "OCI Tokyo Bot (proshanu)"
}
EOF
)
  curl -s -H "Content-Type: application/json" -d "$payload" "$DISCORD_WEBHOOK" > /dev/null 2>&1
}

echo "--- Starting Oracle Instance Creation Retry Script (Tokyo - proshanu) ---" >> "${LOG_FILE}"
echo "Started at $(date '+%Y-%m-%d %H:%M:%S') | PID: $$" >> "${LOG_FILE}"

cd "${DIR}" || { echo "Failed to cd to script directory"; exit 1; }

# Send startup notification
send_discord "🔄 **OCI Retry Script Started (Tokyo - proshanu)** | PID: $$ | Interval: 30 sec | $(date '+%Y-%m-%d %H:%M:%S UTC')"

ATTEMPT=0

# Infinite loop to retry terraform apply
while true; do
  ATTEMPT=$((ATTEMPT + 1))

  # Rotate log if too large
  rotate_log

  echo "$(date '+%Y-%m-%d %H:%M:%S') - [Attempt #${ATTEMPT}] Running terraform apply..." >> "${LOG_FILE}"

  # Run terraform apply automatically
  OUTPUT=$(terraform apply -auto-approve 2>&1)
  EXIT_CODE=$?

  # Append terraform output to log
  echo "$OUTPUT" >> "${LOG_FILE}"

  if [ $EXIT_CODE -eq 0 ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ✅ SUCCESS: Terraform apply completed successfully! (Attempt #${ATTEMPT})" >> "${LOG_FILE}"
    echo "Instance created. Stopping script." >> "${LOG_FILE}"

    # Send success notification to Discord
    send_discord "🎉 **SUCCESS! OCI Tokyo Instance Created (proshanu)!** 🎉\n\n✅ Shape: VM.Standard.A1.Flex\n📍 Region: ap-tokyo-1\n🔢 Attempt: #${ATTEMPT}\n⏰ Time: $(date '+%Y-%m-%d %H:%M:%S UTC')\n\n**Next steps:** SSH in, resize to 4 OCPU / 24 GB / 200 GB"

    break
  else
    # Check for rate-limiting
    if echo "$OUTPUT" | grep -qiE "\b429\b|TooMany|too_many_requests"; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') - ⚠️ RATE LIMITED! Waiting 10 minutes..." >> "${LOG_FILE}"
      send_discord "⚠️ **Rate Limited! (Tokyo - proshanu)** Backing off for 10 minutes. Attempt #${ATTEMPT}"
      sleep 600
    else
      echo "$(date '+%Y-%m-%d %H:%M:%S') - FAILED: Terraform apply failed (exit code $EXIT_CODE). Retrying in 30 seconds... [Attempt #${ATTEMPT}]" >> "${LOG_FILE}"
      sleep 30
    fi
  fi
done