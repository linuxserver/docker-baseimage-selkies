#!/usr/bin/env bash

# Enable Nvidia GPU support if detected
if which nvidia-smi > /dev/null 2>&1 && ls -A /dev/dri 2>/dev/null && [ "${DISABLE_ZINK,,}" == "false" ]; then
  export LIBGL_KOPPER_DRI2=1
  export MESA_LOADER_DRIVER_OVERRIDE=zink
  export GALLIUM_DRIVER=zink
fi

# Start DE
# Distro-aware (task 2, 2026-08-28): RHEL9 ships standard GNOME — boot
# gnome-shell directly (NRP-proven pattern, findings F44/F47); on images
# without gnome-shell (Debian/Fedora) this whole branch is a no-op and the
# original openbox exec runs. Opt out on rhel9 with DESKTOP=openbox.
if [ -x /usr/bin/gnome-shell ] && [ "${DESKTOP}" != "openbox" ]; then
  export XDG_SESSION_TYPE=x11
  export XDG_SESSION_ID="${DISPLAY#:}"
  export XDG_CURRENT_DESKTOP=GNOME
  export DESKTOP_SESSION=gnome
  # fresh per-boot runtime dir: /config/.XDG is on the persistent volume and
  # would keep a stale dbus socket across container restarts (F48); NRP uses
  # the same pattern (their Dockerfile:40)
  export XDG_RUNTIME_DIR=/tmp/runtime-abc
  mkdir -p "$XDG_RUNTIME_DIR" && chmod 0700 "$XDG_RUNTIME_DIR"
  xsetroot -solid "#2d2d2d" 2>/dev/null || true
  # wait for GLX readiness (mutter composites via software GL)
  for i in $(seq 1 30); do
    glxinfo 2>/dev/null | grep -q "OpenGL renderer string" && break
    sleep 1
  done
  # session bus on a deterministic socket: dbus-run-session honors neither
  # XDG_RUNTIME_DIR nor a fixed path on EL9 (falls back to a random /tmp
  # socket from the default session.conf), which gnome-shell and
  # user-launched apps cannot discover
  dbus-daemon --session --nofork --address="unix:path=$XDG_RUNTIME_DIR/bus" &
  DBUS_PID=$!
  export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"
  for i in $(seq 1 50); do
    [ -S "$XDG_RUNTIME_DIR/bus" ] && break
    sleep 0.2
  done
  # SLU wallpaper (user-provided, 2026-08-28): point GNOME's background schema
  # at the bundled image. gnome-shell's background actor reads these keys;
  # gsettings writes land in the dconf user DB under /config and are
  # re-applied idempotently on every boot.
  gsettings set org.gnome.desktop.background picture-uri "file:///usr/share/backgrounds/slu-rhel.jpg" 2>/dev/null || true
  gsettings set org.gnome.desktop.background picture-uri-dark "file:///usr/share/backgrounds/slu-rhel.jpg" 2>/dev/null || true
  # NOTE: RHEL9/GNOME40 enum values differ from Fedora naming (spanned, not span)
  gsettings set org.gnome.desktop.background picture-options "spanned" 2>/dev/null || true
  /usr/bin/gnome-shell --x11 --sm-disable &
  GNOME_PID=$!
  # No auto-apps under GNOME (user decision 2026-08-28): clean desktop,
  # apps launched from the GNOME app grid. openbox mode (DESKTOP=openbox)
  # keeps the LSIO autostart + RESTART_APP contract (svc-watchdog pgreps
  # the `sh ~/.config/openbox/autostart` process).
  wait "$GNOME_PID"
  kill "$DBUS_PID" 2>/dev/null || true
else
  exec dbus-launch --exit-with-session /usr/bin/openbox-session > /dev/null 2>&1
fi
