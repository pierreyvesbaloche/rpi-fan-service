#!/bin/bash

SERVICE_NAME="rpi-fan"
SERVICE_PATH="${RPI_FAN_SERVICE_PATH:-/etc/systemd/system/${SERVICE_NAME}.service}"

printf "rpi-fan Python Service: Installer\n\n"

if [ "$(id -u)" -ne 0 ]; then
	printf "Script must be run as root. Try 'sudo ./install.sh'\n"
	exit 1
fi

function run_as_user {
	# Run a command as the target user, keeping ownership of ~/tools
	# (application + virtual environment) with the user (never root).
	if command -v sudo > /dev/null 2>&1; then
		sudo -u "$TARGET_USER" -- "$@"
	elif [ "$(id -u)" -eq 0 ]; then
		su -s /bin/sh -c "sh -c \"$(printf '%q ' "$@")\"" "$TARGET_USER"
	else
		printf "Cannot drop to user '%s'.\n" "$TARGET_USER"
		exit 1
	fi
}

function fail {
	printf "ERROR: %s\n" "$1"
	exit 1
}

# --- Step 1: update the system and install required packages -------------
MISSING_PKGS=()
for PACKAGE in python3-pip python3-rpi.gpio python3-venv git; do
	printf "Checking for %s\n" "$PACKAGE"
	dpkg -L "$PACKAGE" > /dev/null 2>&1
	if [ "$?" -eq 1 ]; then
		MISSING_PKGS+=("$PACKAGE")
	fi
done
if [ "${#MISSING_PKGS[@]}" -gt 0 ]; then
	printf "Installing missing packages: %s\n" "${MISSING_PKGS[*]}"
	apt-get update
	apt-get install -y "${MISSING_PKGS[@]}"
else
	printf "All required packages are already installed.\n"
fi

# --- Steps 2-3: resolve the target user and create the tools folder -------
if [ -n "$SUDO_USER" ]; then
	TARGET_USER="$SUDO_USER"
else
	# Running as root directly (or via a passwordless sudo wrapper):
	# pick the first non-root account that has a home directory.
	TARGET_USER=$(awk -F: 'NR > 1 && $3 >= 1000 {print $1; exit}' /etc/passwd)
fi
[ -n "$TARGET_USER" ] || fail "Cannot determine the target user to install for."
TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
[ -n "$TARGET_HOME" ] || fail "No home directory found for user '$TARGET_USER'."

printf "Installing for user: %s (%s)\n" "$TARGET_USER" "$TARGET_HOME"

TOOLS_DIR="$TARGET_HOME/tools"
mkdir -p "$TOOLS_DIR"
printf "Created tools folder: %s\n" "$TOOLS_DIR"

# --- Step 4: create the virtual environment inside ~/tools ----------------
VENV_DIR="$TOOLS_DIR/rpi-fan-env"
if [ -x "$VENV_DIR/bin/python3" ]; then
	printf "Virtual environment already exists: %s\n" "$VENV_DIR"
else
	printf "Creating virtual environment: %s\n" "$VENV_DIR"
	run_as_user bash -c "cd '$TOOLS_DIR' && python3 -m venv --system-site-packages rpi-fan-env" \
		|| fail "Could not create the virtual environment."
fi

# --- Step 5: copy rpi-fan-custom.py from this repository into ~/tools -----
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" > /dev/null 2>&1 && pwd)"
SRC_PY="$SCRIPT_DIR/rpi-fan-custom.py"
[ -f "$SRC_PY" ] || fail "Missing $SRC_PY (is this the rpi-fan repository?)"
cp "$SRC_PY" "$TOOLS_DIR/"
printf "Copied rpi-fan-custom.py to %s/\n" "$TOOLS_DIR"

# --- Steps 6-7: upgrade pip inside the virtual environment -----------------
# (Activating the venv is implicit: its pip binary is used directly, which
# is equivalent to 'source .../bin/activate && pip install --upgrade pip'.)
printf "Upgrading pip in the virtual environment\n"
run_as_user bash -c "'$VENV_DIR/bin/pip' install --upgrade pip" \
	|| fail "Could not upgrade pip in the virtual environment."

# --- Step 8: create the systemd service, tailored to the target user ------
printf "Installing service: %s\n" "$SERVICE_PATH"
cat > "$SERVICE_PATH" << EOF
[Unit]
Description=NXEZ Fan and LED Controller
After=network.target

[Service]
Type=simple
User=$TARGET_USER
WorkingDirectory=$TOOLS_DIR
ExecStart=$VENV_DIR/bin/python3 -u $TOOLS_DIR/rpi-fan-custom.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
chown -R "$TARGET_USER" "$TOOLS_DIR"

# --- Steps 9-10: reload the daemon and start the service ------------------
printf "Reloading systemd daemon\n"
systemctl daemon-reload
systemctl enable "$SERVICE_NAME" > /dev/null 2>&1
systemctl start "$SERVICE_NAME" || fail "Could not start the $SERVICE_NAME service."
systemctl status --no-pager "$SERVICE_NAME"

printf "Done!\n"
