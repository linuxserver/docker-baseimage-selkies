#!/usr/bin/env bash

# Start DE
ulimit -c 0
export XCURSOR_THEME=breeze_cursors
export XCURSOR_SIZE=24
export XKB_DEFAULT_LAYOUT=us
export XKB_DEFAULT_RULES=evdev
export WAYLAND_DISPLAY=wayland-1

if [ "${PELORUS,,}" == "true" ]; then
  export QT_ACCESSIBILITY=1
  export QT_LINUX_ACCESSIBILITY_ALWAYS_ON=1
  export GTK_MODULES=gail:atk-bridge
  export MOZ_ENABLE_WAYLAND=0
  if [ "${SELKIES_DESKTOP,,}" == "true" ]; then
    dbus-run-session bash -c '
      /usr/libexec/at-spi2-registryd &
      ATSPI_PID=$!
      pelorus &
      PELORUS_PID=$!
      labwc -i &
      LABWC_PID=$!
      sleep 1
      export WAYLAND_DISPLAY=wayland-0
      export DISPLAY=:0
      selkies-desktop
      kill $ATSPI_PID
      kill $LABWC_PID
      kill $PELORUS_PID
    '
  else
    dbus-run-session bash -c '
      /usr/libexec/at-spi2-registryd &
      ATSPI_PID=$!
      pelorus &
      PELORUS_PID=$!
      labwc -i
      kill $ATSPI_PID
      kill $PELORUS_PID
    '
  fi
else
  if [ "${SELKIES_DESKTOP,,}" == "true" ]; then
    labwc &
    LABWC_PID=$!
    sleep 1
    export WAYLAND_DISPLAY=wayland-0
    export DISPLAY=:0
    selkies-desktop
    kill $LABWC_PID
  else
    labwc
  fi
fi
