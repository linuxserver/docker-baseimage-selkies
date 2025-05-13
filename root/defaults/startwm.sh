#!/usr/bin/env bash

# Check for any render nodes
for node in /dev/dri/renderD*; do
    if [ -e "$node" ]; then
        render_node_exists=true
        break
    fi
done
# Enable Zink support if detected
if [ "$render_node_exists" = true ] && [ "${DISABLE_ZINK}" == "false" ]; then
  export LIBGL_KOPPER_DRI2=1
  export MESA_LOADER_DRIVER_OVERRIDE=zink
  export GALLIUM_DRIVER=zink
fi

/usr/bin/openbox-session
