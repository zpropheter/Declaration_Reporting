#!/bin/bash

OUTPUT_FILE="/var/log/update_declarations.json"

LAST_BLOCK=$(log show --style syslog --info --source \
  --predicate '(process == "SoftwareUpdateSubscriber") AND (eventMessage CONTAINS "softwareupdate.")' \
  --last 1d \
  | awk '
    /Reporting status {/ {in_block=1; block=""; block=block $0 "\n"; next}
    in_block {block=block $0 "\n"}
    /\} \(null\)/ {if (in_block) {last_block=block; in_block=0}}
    END {print last_block}
  ')


# Extract top-level values
DEVICE_ID=$(echo "$LAST_BLOCK" | grep '"softwareupdate.device-id"' | tail -1 | awk -F'= ' '{gsub(/;|"/,"",$2); print $2}')
INSTALL_STATE=$(echo "$LAST_BLOCK" | grep '"softwareupdate.install-state"' | tail -1 | awk -F'= ' '{gsub(/;|"/,"",$2); print $2}')
TARGET_LOCAL_DATE=$(echo "$LAST_BLOCK" | grep '"softwareupdate.target-local-date-time"' | tail -1 | awk -F'= ' '{gsub(/;|"/,"",$2); print $2}')

# Nested: failure-reason -> reason
FAILURE_REASON=$(echo "$LAST_BLOCK" | awk '/"softwareupdate.failure-reason"/,/}/' \
  | grep 'reason' | awk -F'= ' '{gsub(/;|"/,"",$2); print $2}')

# Nested: install-reason -> reason
INSTALL_REASON=$(echo "$LAST_BLOCK" | awk '/"softwareupdate.install-reason"/,/}/' \
  | grep 'reason' | awk -F'= ' '{gsub(/;|"/,"",$2); print $2}')

# Nested: pending-version subkeys
BUILD_VERSION=$(echo "$LAST_BLOCK" | awk '/"softwareupdate.pending-version"/,/}/' \
  | grep 'build-version' | awk -F'= ' '{gsub(/;|"/,"",$2); print $2}')
OS_VERSION=$(echo "$LAST_BLOCK" | awk '/"softwareupdate.pending-version"/,/}/' \
  | grep 'os-version' | awk -F'= ' '{gsub(/;|"/,"",$2); print $2}')
PENDING_DATE=$(echo "$LAST_BLOCK" | awk '/"softwareupdate.pending-version"/,/}/' \
  | grep 'target-local-date-time' | awk -F'= ' '{gsub(/;|"/,"",$2); print $2}')

# Write JSON
cat <<EOF | tr -d '\000-\037' > "$OUTPUT_FILE"
{
  "softwareupdate.device-id": "$DEVICE_ID",
  "softwareupdate.failure-reason": "$FAILURE_REASON",
  "softwareupdate.install-reason": "$INSTALL_REASON",
  "softwareupdate.install-state": "$INSTALL_STATE",
  "softwareupdate.pending-version": {
    "build-version": "$BUILD_VERSION",
    "os-version": "$OS_VERSION",
    "target-local-date-time": "$PENDING_DATE"
  },
  "softwareupdate.target-local-date-time": "$TARGET_LOCAL_DATE"
}
EOF

# Output timestamp
echo "<result>$(date +"%Y-%m-%d %H:%M:%S")</result>"
