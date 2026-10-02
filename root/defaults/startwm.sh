#!/usr/bin/env bash

# fd 3 is opened by svc-de/run and follows SELKIES_DEBUG, stay quiet without it
[ -e /proc/self/fd/3 ] || exec 3>/dev/null

# Start DE
if [ "${SELKIES_DESKTOP,,}" == "true" ]; then
  exec dbus-launch --exit-with-session /usr/bin/openbox-session >&3 2>&3 &
  OPENBOX_PID=$!
  sleep 1
  selkies-desktop
  kill $OPENBOX_PID
else
  exec dbus-launch --exit-with-session /usr/bin/openbox-session >&3 2>&3
fi
