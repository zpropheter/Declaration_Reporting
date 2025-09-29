#!/bin/bash

OUTPUT_FILE="/var/log/update_declarations.json"
TMP_PLIST=$(mktemp /tmp/su_block.XXXX.plist)

# Extract the most recent Reporting status block
BLOCK=$(log show --style syslog --info --source \
  --predicate '(process == "SoftwareUpdateSubscriber") AND (eventMessage CONTAINS "softwareupdate.")' --last 1d \
  | awk '/Reporting status {/,/} \(null\)/' \
  | sed '1d;$d')

# Initialize plist
echo "<plist version=\"1.0\"><dict>" > "$TMP_PLIST"

# Stack to track nested dicts
declare -a STACK
STACK=("root")

while IFS= read -r line; do
    # Trim leading/trailing spaces and trailing semicolon
    LINE=$(echo "$line" | sed 's/^[[:space:]]*//; s/;$//')

    # Skip empty lines
    [[ -z "$LINE" ]] && continue

    # Match key = value
    if [[ "$LINE" =~ \"([^\"]+)\"[[:space:]]*=[[:space:]]*(.*) ]]; then
        KEY="${BASH_REMATCH[1]}"
        VALUE="${BASH_REMATCH[2]}"

        if [[ "$VALUE" == "{" ]]; then
            # Start nested dict
            echo "<key>$KEY</key><dict>" >> "$TMP_PLIST"
            STACK+=("dict")
            continue
        elif [[ "$VALUE" == "(" ]]; then
            # Start array
            echo "<key>$KEY</key><array>" >> "$TMP_PLIST"
            STACK+=("array")
            continue
        else
            # Plain value
            if [[ "$VALUE" =~ ^[0-9]+$ ]]; then
                echo "<key>$KEY</key><integer>$VALUE</integer>" >> "$TMP_PLIST"
            elif [[ "$VALUE" == "none" || "$VALUE" == "null" ]]; then
                echo "<key>$KEY</key><string>$VALUE</string>" >> "$TMP_PLIST"
            else
                echo "<key>$KEY</key><string>$VALUE</string>" >> "$TMP_PLIST"
            fi
            continue
        fi
    fi

    # Handle array elements: e.g., reason = ( ... )
    if [[ "$LINE" =~ ^([^\=]+)[[:space:]]*=[[:space:]]*\((.*)\) ]]; then
        KEY="${BASH_REMATCH[1]}"
        ELEMENTS="${BASH_REMATCH[2]}"
        echo "<key>$KEY</key><array>" >> "$TMP_PLIST"
        for ITEM in $ELEMENTS; do
            [[ -n "$ITEM" ]] && echo "<string>$ITEM</string>" >> "$TMP_PLIST"
        done
        echo "</array>" >> "$TMP_PLIST"
        continue
    fi

    # Close dict or array
    if [[ "$LINE" == "}" ]]; then
        TYPE="${STACK[-1]}"
        unset STACK[-1]
        if [[ "$TYPE" == "dict" ]]; then
            echo "</dict>" >> "$TMP_PLIST"
        elif [[ "$TYPE" == "array" ]]; then
            echo "</array>" >> "$TMP_PLIST"
        fi
    fi

done <<< "$BLOCK"

echo "</dict></plist>" >> "$TMP_PLIST"

# Convert plist to JSON
plutil -convert json -o "$OUTPUT_FILE" "$TMP_PLIST"

# Clean up temp file
rm "$TMP_PLIST"

# Output timestamp for Jamf Extension Attribute
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
echo "<result>$TIMESTAMP</result>"
