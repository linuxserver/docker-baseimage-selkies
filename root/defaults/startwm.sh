#!/usr/bin/env bash

# Enable Nvidia GPU support if detected
if which nvidia-smi > /dev/null 2>&1 && ls -A /dev/dri 2>/dev/null && [ "${DISABLE_ZINK,,}" == "false" ]; then
  export LIBGL_KOPPER_DRI2=1
  export MESA_LOADER_DRIVER_OVERRIDE=zink
  export GALLIUM_DRIVER=zink
fi

# Start DE. Output goes wherever svc-de/run pointed it, so SELKIES_DEBUG
# decides whether the session's own logs are kept.
exec dbus-launch --exit-with-session /usr/bin/openbox-session
