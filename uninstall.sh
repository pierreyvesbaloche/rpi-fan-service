#!/bin/bash

SERVICE_NAME="rpi-fan"
SERVICE_PATH="${RPI_FAN_SERVICE_PATH:-/etc/systemd/system/${SERVICE_NAME}.service}"

printf "rpi-fan Python Service: Uninstaller\n\n"

if [ "$(id -u)" -ne 0 ]; then
	printf "Script must be run as root. Try 'sudo ./uninstall.sh'\n"
	exit 1
fi

# --- Stop and disable the service -----------------------------------------
printf "Stopping and disabling service: %s\n" "$SERVICE_NAME"
systemctl stop "$SERVICE_NAME" 2> /dev/null || true
systemctl disable "$SERVICE_NAME" 2> /dev/null || true

# --- Remove the systemd unit and reload the daemon ------------------------
if [ -f "$SERVICE_PATH" ]; then
	printf "Removing service: %s\n" "$SERVICE_PATH"
	rm -f "$SERVICE_PATH"
fi
systemctl daemon-reload

# --- Remove the application files and the virtual environment -------------
if [ -n "$SUDO_USER" ]; then
	TARGET_USER="$SUDO_USER"
else
	TARGET_USER=$(awk -F: 'NR > 1 && $3 >= 1000 {print $1; exit}' /etc/passwd)
fi
TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)

if [ -f "$TARGET_HOME/tools/rpi-fan-custom.py" ]; then
	printf "Removing %s/tools/rpi-fan-custom.py\n" "$TARGET_HOME"
	rm -f "$TARGET_HOME/tools/rpi-fan-custom.py"
fi

if [ -d "$TARGET_HOME/tools/rpi-fan-env" ]; then
	printf "Removing virtual environment: %s/tools/rpi-fan-env\n" "$TARGET_HOME"
	rm -rf "$TARGET_HOME/tools/rpi-fan-env"
fi

printf "Done!\n"
