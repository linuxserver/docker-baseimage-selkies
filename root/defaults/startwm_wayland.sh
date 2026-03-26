#!/usr/bin/env bash

# Start DE
ulimit -c 0
export XCURSOR_THEME=whiteglass
export XCURSOR_SIZE=24
export XKB_DEFAULT_LAYOUT=us
export XKB_DEFAULT_RULES=evdev
export WAYLAND_DISPLAY=wayland-1
if [ "${SELKIES_DESKTOP}" == "true" ]; then
  labwc > /dev/null 2>&1 &
  sleep 1
  export WAYLAND_DISPLAY=wayland-0
  export DISPLAY=:0
  selkies-desktop
else
  labwc > /dev/null 2>&1
fi
