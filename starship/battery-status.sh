#!/usr/bin/env bash

BATTERY_INFO=$(pmset -g batt)
PERCENT=$(echo "$BATTERY_INFO" | grep -o '[0-9]\+%' | tr -d '%')
STATE=$(echo "$BATTERY_INFO" | grep -o 'AC Power\|Battery Power\|charged')

get_icon() {
  case $1 in
  [0-9] | 1[0-4]) echo "" ;;
  1[5-9] | 2[0-4]) echo "" ;;
  2[5-9] | 3[0-4]) echo "" ;;
  3[5-9] | 4[0-4]) echo "" ;;
  4[5-9] | 5[0-4]) echo "" ;;
  5[5-9] | 6[0-4]) echo "" ;;
  6[5-9] | 7[0-4]) echo "" ;;
  7[5-9] | 8[0-4]) echo "" ;;
  8[5-9] | 9[0-4]) echo "" ;;
  9[5-9] | 100) echo "" ;;
  *) echo "🔋" ;;
  esac
}

ICON=""
if [[ "$STATE" == "AC Power" && "$PERCENT" -eq 100 ]]; then
  ICON="🔌" # Plugged in & full
elif [[ "$STATE" == "AC Power" ]]; then
  ICON="⚡️" # Charging
else
  ICON=$(get_icon "$PERCENT") # On battery
fi

echo "$ICON ${PERCENT}%"
exit 0
