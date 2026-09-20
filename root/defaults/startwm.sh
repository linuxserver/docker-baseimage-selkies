#!/usr/bin/env bash

# Start DE
if [ "${SELKIES_DESKTOP,,}" == "true" ]; then
  exec dbus-launch --exit-with-session /usr/bin/openbox-session > /dev/null 2>&1 &
  OPENBOX_PID=$!
  sleep 1
  selkies-desktop
  kill $OPENBOX_PID
else
  exec dbus-launch --exit-with-session /usr/bin/openbox-session > /dev/null 2>&1
fi
