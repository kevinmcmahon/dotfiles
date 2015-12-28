#!/usr/bin/env bash

CONFIG_DIR=/Library/Preferences/SystemConfiguration
BACKUP_DIR="${HOME}/Desktop/Backup WiFi Settings"

#####

echo 'Getting superuser permissionsâ€¦'
sudo echo '  Superuser enabled'

#####

echo 'Shutting off WiFi'
networksetup -listallhardwareports | grep -A 1 Wi-Fi | grep Device: | awk '{ print $2 }' | while read DEVICE
do
  echo "  ${DEVICE}"
  networksetup -setairportpower "${DEVICE}" off
  sleep 15
done

#####

echo 'Saving old settings...'
mkdir -p "${BACKUP_DIR}"
for FILE in com.apple.airport.preferences.plist \
            com.apple.network.identification.plist \
            com.apple.wifi.message-tracer.plist \
            NetworkInterfaces.plist \
            preferences.plist
do
  if [ -f "${CONFIG_DIR}/${FILE}" ]
  then
    echo "  ${FILE}"
    sudo mv "${CONFIG_DIR}/${FILE}" "${BACKUP_DIR}/"
  fi
done

#####

echo 'Reboot your computer'