#!/bin/bash

WEB_PATH="https://raw.githubusercontent.com/williamwutq/wannasleep/main/"
RECENT_BUILD="0.1.2-nightly-2026-01-15-debug"

# Auto-update this script
curl -s "${WEB_PATH}install.sh" -o /tmp/install.sh.new
if ! cmp -s /tmp/install.sh.new "$0"; then
    echo "A new version of the install script is available. Updating..."
    mv /tmp/install.sh.new "$0"
    chmod +x "$0"
    echo "Restarting the installation with the updated script..."
    exec "$0" "$@"
    exit 0
else
    rm /tmp/install.sh.new
fi

# Detect OS and architecture
ARCH="$(uname -m)"
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"

if [[ "$OS" == "darwin" ]]; then
	OS="macos"
elif [[ "$OS" == "linux" ]]; then
	OS="linux"
else
	echo "Windows or unsupported OS detected. Exiting."
	exit 1
fi

case "$ARCH" in
	x86_64)
		PREFIX="x86_64-$OS-"
		;;
	aarch64|arm64)
		PREFIX="aarch64-$OS-"
		;;
	*)
		echo "Unsupported architecture: $ARCH"
		exit 1
		;;
esac

FILE_NAME="${PREFIX}-${RECENT_BUILD}"
DOWNLOAD_URL="${WEB_PATH}builds/${FILE_NAME}"
INSTALL_PATH="/usr/local/bin/todo"
echo "Downloading the latest build from $DOWNLOAD_URL ..."
curl -L "$DOWNLOAD_URL" -o "/tmp/${FILE_NAME}"
if [[ $? -ne 0 ]]; then
    echo "Failed to download. Please check your internet connection and try again."
    rm -f "/tmp/${FILE_NAME}"
    exit 1
fi
curl -L "${WEB_PATH}todo.1" -o "/tmp/todo.1"
if [[ $? -ne 0 ]]; then
    echo "Failed to download. Please check your internet connection and try again."
    rm -f "/tmp/todo.1"
    exit 1
fi
chmod +x "/tmp/${FILE_NAME}"
sudo mv "/tmp/${FILE_NAME}" "$INSTALL_PATH"
sudo mv "/tmp/todo.1" "/usr/local/share/man/man1/todo.1"

echo "Installation complete. You can now use the 'todo' command."