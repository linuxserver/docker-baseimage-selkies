#!/usr/bin/env bash

# Enable Nvidia GPU support if detected
if which nvidia-smi && [ "${DISABLE_ZINK}" == "false" ]; then
  export LIBGL_KOPPER_DRI2=1
  export MESA_LOADER_DRIVER_OVERRIDE=zink
  export GALLIUM_DRIVER=zink
fi

# Dbus defaults
export XDG_RUNTIME_DIR="/tmp/xdg-runtime-abc"
mkdir -p -m700 "${XDG_RUNTIME_DIR}"

# Start DE
exec dbus-launch --exit-with-session /usr/bin/openbox-session > /dev/null 2>&1
