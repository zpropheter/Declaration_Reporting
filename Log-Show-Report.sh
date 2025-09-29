log show --style syslog --info --source \
  --predicate '(process == "SoftwareUpdateSubscriber") AND (eventMessage CONTAINS "softwareupdate.")' --last 1d \
| awk '/Reporting status {/,/} \(null\)/' \
| tail -r | awk '/Reporting status {/,/} \(null\)/' | tail -r \
| tail -n +2 | head -n -1 \
| sed -E 's/^[[:space:]]*"([^"]+)" = (.*);$/\"\1\": \2,/' \
| sed -E 's/^[[:space:]]*([a-zA-Z0-9._-]+) = (.*);$/\"\1\": \2,/' \
| sed -E 's/\((.*)\)/\[\1\]/g' \
| sed -E 's/([a-zA-Z0-9._-]+) = \{/\"\1\": {/' \
| sed -E 's/};/}/g' \
| sed -E 's/,$//' \
| sed '1s/^/{/;$s/,$/}/' \
| jq .
