#!/bin/bash
# Reports GNOME desktop activity to Home Assistant as binary_sensor.computer_active.
# Turns "on" only after input in two polls in a row (a single stray event from a
# mouse or the display waking at night doesn't count), and back "off" after
# 2 minutes without input. Reports "off" when the idle time can't be read
# (no session) and when the service stops, so the sensor never stays stuck "on".
TOKEN=$(cat "${HA_TOKEN_FILE:-$HOME/.config/ha-idle/token}")
URL="http://localhost:8123/api/states/binary_sensor.computer_active"
IDLE_LIMIT_MS=120000
RECENT_MS=30000
STATE=off
PREV_RECENT=0

report() {
  curl -s -o /dev/null -X POST "$URL" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"state\": \"$1\", \"attributes\": {\"friendly_name\": \"Computer active\", \"idle_seconds\": $2}}"
}

trap 'report off -1; exit 0' TERM INT

while true; do
  IDLE_MS=$(gdbus call --session --dest org.gnome.Mutter.IdleMonitor \
    --object-path /org/gnome/Mutter/IdleMonitor/Core \
    --method org.gnome.Mutter.IdleMonitor.GetIdletime 2>/dev/null | grep -oP 'uint64 \K[0-9]+')
  if [ -z "$IDLE_MS" ]; then
    STATE=off
    PREV_RECENT=0
    report off -1
  else
    RECENT=0
    [ "$IDLE_MS" -lt "$RECENT_MS" ] && RECENT=1
    if [ "$STATE" = on ]; then
      [ "$IDLE_MS" -ge "$IDLE_LIMIT_MS" ] && STATE=off
    elif [ "$RECENT" = 1 ] && [ "$PREV_RECENT" = 1 ]; then
      STATE=on
    fi
    PREV_RECENT=$RECENT
    report $STATE $((IDLE_MS/1000))
  fi
  sleep 30 &
  wait $!
done
