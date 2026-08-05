#!/usr/bin/env bash

# Enable Nvidia GPU support if detected
if which nvidia-smi > /dev/null 2>&1 && ls -A /dev/dri 2>/dev/null && [ "${DISABLE_ZINK,,}" == "false" ]; then
  export LIBGL_KOPPER_DRI2=1
  export MESA_LOADER_DRIVER_OVERRIDE=zink
  export GALLIUM_DRIVER=zink
fi

# Start DE. Output is discarded by default; SELKIES_DEBUG surfaces the openbox
# session and everything it launches (autostart, app launchers, ready banners)
# in the container log.
if [ "${SELKIES_DEBUG,,}" = "true" ]; then LOGDEST=/dev/stdout; else LOGDEST=/dev/null; fi
exec dbus-launch --exit-with-session /usr/bin/openbox-session > "${LOGDEST}" 2>&1
