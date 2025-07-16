#!/usr/bin/env bash

# Dbus defaults
export XDG_RUNTIME_DIR="/tmp/xdg-runtime-abc"
mkdir -p -m700 "${XDG_RUNTIME_DIR}"

# Start DE
exec dbus-launch --exit-with-session /usr/bin/openbox-session > /dev/null 2>&1
