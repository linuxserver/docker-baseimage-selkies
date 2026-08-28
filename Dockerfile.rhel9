# syntax=docker/dockerfile:1
#
# RHEL9 variant (SLU) — PLAN v4, approved 2026-08-27
#   Plan:    memory-bank/activeContext.md#PLAN-v4
#   Vetting: memory-bank/tasks/2026-08/270827_rhel9-vetting-plan-v4.md
#   Findings: memory-bank/findings.md (F01-F30)
#
# Model: upstream fedora44's Dockerfile with EL9 substitutions (NOT a Debian
# port), on an SLU-owned UBI9 base stage with entitled RHEL repos.
#
# BUILD CONSTRAINT (F03): builds ONLY on a subscription-registered RHEL 9.x
# host — podman auto-mounts host entitlements into builds ("container mode").
# Preflight (once per host):
#   podman run --rm registry.access.redhat.com/ubi9/ubi dnf repolist
# must list rhel-9-for-x86_64-{baseos,appstream}-rpms. Runtime needs no
# entitlement (NRP just pulls).
#
# Phase-1 scope: CPU desktop + streaming (Xvfb, openbox, selkies, nginx,
# pulseaudio). Deferred to phase 2: DinD, GPU/Zink (F06/F07/F29), proot-apps,
# pelorus, Wayland/labwc, DEV_MODE (gated off below).
#
# Base pin: phase 1 pins the x86_64 manifest digest (verified 2026-08-27);
# unpin to the tag once the variant stabilizes.

# =============================================================================
# Stage: base — SLU-owned UBI9 + s6-overlay
#
# Mechanics vendored from linuxserver/docker-baseimage-el (DEPRECATED — F02)
# with deliberate omissions per the 2026-08-27 SLU-owned base ADR:
#   * NO oracle-linux-ol9.repo / RPM-GPG-KEY-oracle (F01: content is
#     registered RHEL, not Oracle mirrors)
#   * NO subscription-manager disable (entitlement passthrough is the
#     mechanism; disabling it would break dnf in the runtime stage)
#   * NO RPMFusion (only mattered for deferred phase-2 DEV_MODE ffmpeg)
#   * + EPEL9 (desktop delta absent from all RHEL repos — F04)
# =============================================================================
FROM registry.access.redhat.com/ubi9/ubi@sha256:03b3d228574922e50bc654aea24a213f68467937c5cc001b5786815152d6f4e2 AS base

# args
ARG MODS_VERSION="v3"
ARG PKG_INST_VERSION="v1"
ARG LSIOWN_VERSION="v1"
ARG WITHCONTENV_VERSION="v1"
ARG S6_OVERLAY_VERSION="3.2.0.2"
ARG S6_OVERLAY_ARCH="x86_64"

# EPEL9 — desktop delta (openbox, st, xsettingsd, ...). NRP-proven on UBI9.
RUN \
  echo "**** EPEL9 ****" && \
  dnf install -y \
    https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm

# base tools (baseimage-el parity)
RUN \
  echo "**** base tools ****" && \
  dnf -y --setopt=install_weak_deps=False --best install --allowerasing \
    busybox \
    ca-certificates \
    catatonit \
    coreutils \
    curl \
    findutils \
    hostname \
    jq \
    netcat \
    procps \
    shadow \
    tzdata \
    xz \
    which

# user setup (LSIO convention: abc uid 911, HOME=/config)
RUN \
  echo "**** user setup ****" && \
  useradd -u 911 -U -d /config -s /bin/false abc && \
  usermod -G users abc && \
  mkdir -p \
    /app \
    /config \
    /defaults \
    /lsiopy && \
  chown abc:users /config

# s6-overlay (noarch + arch + optional symlinks; docker-mods' with-contenv
# replaces the s6 one, as in every LSIO base)
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz /tmp
RUN tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-${S6_OVERLAY_ARCH}.tar.xz /tmp
RUN tar -C / -Jxpf /tmp/s6-overlay-${S6_OVERLAY_ARCH}.tar.xz
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-symlinks-noarch.tar.xz /tmp
RUN tar -C / -Jxpf /tmp/s6-overlay-symlinks-noarch.tar.xz && unlink /usr/bin/with-contenv
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-symlinks-arch.tar.xz /tmp
RUN tar -C / -Jxpf /tmp/s6-overlay-symlinks-arch.tar.xz && rm -f /tmp/s6-overlay-*.tar.xz

# docker-mods scripts (LSIO base contract: stage-2 hook, lsiown, with-contenv)
ADD --chmod=744 "https://raw.githubusercontent.com/linuxserver/docker-mods/mod-scripts/docker-mods.${MODS_VERSION}" "/docker-mods"
ADD --chmod=744 "https://raw.githubusercontent.com/linuxserver/docker-mods/mod-scripts/package-install.${PKG_INST_VERSION}" "/etc/s6-overlay/s6-rc.d/init-mods-package-install/run"
ADD --chmod=744 "https://raw.githubusercontent.com/linuxserver/docker-mods/mod-scripts/lsiown.${LSIOWN_VERSION}" "/usr/bin/lsiown"
ADD --chmod=755 "https://raw.githubusercontent.com/linuxserver/docker-mods/mod-scripts/with-contenv.${WITHCONTENV_VERSION}" "/usr/bin/with-contenv"

# vendored LSIO base s6-rc.d services (root-base/) — the init chain the shared
# selkies tree depends on (init-os-end, init-mods, init-services, ...).
# Source: linuxserver/docker-baseimage-el root/etc/s6-overlay, with the Oracle
# repo file + GPG key deliberately excluded (ADR 2026-08-27).
COPY root-base/ /

# cleanup
RUN \
  dnf autoremove -y && \
  dnf clean all && \
  rm -rf \
    /tmp/* \
    /var/cache/dnf/*

# LSIO base env (runtime stage overrides HOME to /config)
ENV PS1="$(whoami)@$(hostname):$(pwd)\\$ " \
    HOME="/root" \
    TERM="xterm" \
    S6_CMD_WAIT_FOR_SERVICES_MAXTIME="0" \
    S6_VERBOSITY=1 \
    S6_STAGE2_HOOK=/docker-mods \
    VIRTUAL_ENV=/lsiopy \
    PATH="/lsiopy/bin:$PATH"

# =============================================================================
# Stage: frontend — master verbatim (alpine 3.22, selkies 348bc4f dashboards)
# =============================================================================
FROM ghcr.io/linuxserver/baseimage-alpine:3.22 AS frontend

RUN \
  echo "**** install build packages ****" && \
  apk add \
    cmake \
    git \
    nodejs \
    npm

RUN \
  echo "**** ingest code ****" && \
  git clone \
    https://github.com/selkies-project/selkies.git \
    /src && \
  cd /src && \
  git checkout -f 348bc4f61da66198573e7e57db9a266aca1991d5

RUN \
  echo "**** build shared core library ****" && \
  cd /src/addons/selkies-web-core && \
  npm install && \
  npm run build && \
  echo "**** build multiple dashboards ****" && \
  DASHBOARDS="selkies-dashboard selkies-dashboard-wish" && \
  mkdir /buildout && \
  for DASH in $DASHBOARDS; do \
    cd /src/addons/$DASH && \
    cp ../selkies-web-core/dist/selkies-core.js src/ && \
    npm install && \
    npm run build && \
    mkdir -p dist/src dist/nginx && \
    cp ../selkies-web-core/dist/selkies-core.js dist/src/ && \
    cp ../universal-touch-gamepad/universalTouchGamepad.js dist/src/ && \
    cp ../selkies-web-core/nginx/* dist/nginx/ && \
    cp -r ../selkies-web-core/dist/jsdb dist/ && \
    mkdir -p /buildout/$DASH && \
    cp -ar dist/* /buildout/$DASH/; \
  done

# =============================================================================
# Runtime stage
# =============================================================================
FROM base

# set version label
ARG BUILD_DATE
ARG VERSION
LABEL build_version="SLU version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="Saint Louis University ITS"

# env
# LSIO parity + NRP-proven llvmpipe trio (CPU GL fallback guarantee).
# DISABLE_DRI3=true is a DELIBERATE rhel9 divergence (D5/F16): stock EL9 Xvfb
# has no LSIO -vfbdevice patch; the gate at svc-xorg/run:19 keeps Xvfb up on
# any host/node exposing /dev/dri (NRP GPU nodes).
ENV DISPLAY=:1 \
    PERL5LIB=/usr/local/bin \
    HOME=/config \
    START_DOCKER=true \
    PULSE_RUNTIME_PATH=/defaults \
    SELKIES_INTERPOSER=/usr/lib/selkies_joystick_interposer.so \
    NVIDIA_DRIVER_CAPABILITIES=all \
    DISABLE_ZINK=false \
    DISABLE_DRI3=true \
    LIBGL_ALWAYS_SOFTWARE=1 \
    GALLIUM_DRIVER=llvmpipe \
    MESA_GL_VERSION_OVERRIDE=4.5 \
    SELKIES_ENCODER="x264enc,jpeg" \
    TITLE=Selkies

# NOTE: xorg-x11-server-Xorg (in runtime deps below) is installed although
# phase 1 only RUNS Xvfb: it carries the `cvt`/`gtf` modeline tools that
# selkies' runtime resize path (gst_app_resize) calls when a client requests
# a new display size (F41 — without them the stream aborts: "Waiting for
# stream..."). Upstream el9 shipped the same pair. F08 corrected.
RUN \
  echo "**** install build deps ****" && \
  dnf install -y \
    gcc \
    gcc-c++ \
    glibc-devel \
    kernel-headers \
    make \
    ncurses \
    python3.11-devel && \
  echo "**** install runtime deps ****" && \
  dnf install -y --setopt=install_weak_deps=False \
    breeze-cursor-theme \
    dbus \
    dbus-daemon \
    dbus-x11 \
    dejavu-sans-fonts \
    exo \
    file \
    firefox \
    gedit \
    glibc-all-langpacks \
    glibc-locale-source \
    glx-utils \
    gnome-calculator \
    gnome-screenshot \
    gnome-settings-daemon \
    gnome-session \
    gnome-session-xsession \
    gnome-shell \
    gnome-terminal \
    google-noto-cjk-fonts-common \
    google-noto-emoji-fonts \
    google-noto-sans-cjk-ttc-fonts \
    google-noto-sans-fonts \
    iproute \
    kbd \
    libxkbcommon-devel \
    libva \
    mesa-dri-drivers \
    mesa-libEGL \
    mesa-libGL \
    mesa-libgbm \
    mesa-vulkan-drivers \
    mutter \
    nautilus \
    nginx \
    nginx-mod-fancyindex \
    openbox \
    openssl \
    procps-ng \
    psmisc \
    pulseaudio \
    pulseaudio-utils \
    python3.11 \
    python3.11-libs \
    python3.11-pip \
    shadow-utils \
    st \
    sudo \
    tar \
    util-linux \
    which \
    xclip \
    xdg-utils \
    xdotool \
    xkeyboard-config \
    xkbcomp \
    mkfontscale \
    xorg-x11-fonts-100dpi \
    xorg-x11-fonts-75dpi \
    xorg-x11-fonts-misc \
    xorg-x11-server-utils \
    xorg-x11-server-Xorg \
    xorg-x11-server-Xvfb \
    xorg-x11-utils \
    xorg-x11-xauth \
    xsel \
    xsettingsd \
    xterm

# selkies 348bc4f pulls python xkbcommon/evdev with C extensions.
# xkbcommon is pinned <1.5: python-xkbcommon>=1.5 needs XKB_CONTEXT_NO_SECURE_GETENV
# (added in libxkbcommon 1.5), but RHEL 9 ships libxkbcommon 1.4 on every stream.
# 1.0.1 builds clean against 1.4 (verified in ubi9 container, 2026-08-27).
# evdev needs Python.h (python3.11-devel) — installed in build deps.
RUN \
  echo "**** install selkies ****" && \
  curl -o \
    /tmp/selkies.tar.gz -L \
    "https://github.com/selkies-project/selkies/archive/348bc4f61da66198573e7e57db9a266aca1991d5.tar.gz" && \
  cd /tmp && \
  tar xf selkies.tar.gz && \
  cd selkies-* && \
  sed -i '/"av>/d' pyproject.toml && \
  sed -i '/cryptography/d' pyproject.toml && \
  sed -i 's/xkbcommon/xkbcommon<1.5/g' pyproject.toml && \
  python3.11 \
    -m venv \
    --system-site-packages \
    /lsiopy && \
  pip install . && \
  pip install setuptools && \
  echo "**** install selkies interposer ****" && \
  cd addons/js-interposer && \
  gcc -shared -fPIC -ldl \
    -o selkies_joystick_interposer.so \
    joystick_interposer.c && \
  mv \
    selkies_joystick_interposer.so \
    /usr/lib/selkies_joystick_interposer.so && \
  echo "**** install selkies fake udev ****" && \
  cd ../fake-udev && \
  make && \
  mkdir /opt/lib && \
  mv \
    libudev.so.1.0.0-fake \
    /opt/lib/ && \
  echo "**** add icon ****" && \
  mkdir -p \
    /usr/share/selkies/www && \
  curl -o \
    /usr/share/selkies/www/icon.png \
    https://raw.githubusercontent.com/linuxserver/docker-templates/master/linuxserver.io/img/selkies-logo.png && \
  curl -o \
    /usr/share/selkies/www/favicon.ico \
    https://raw.githubusercontent.com/linuxserver/docker-templates/refs/heads/master/linuxserver.io/img/selkies-icon.ico

RUN \
  echo "**** openbox tweaks ****" && \
  sed -i \
    -e 's/NLIMC/NLMC/g' \
    -e 's|</applications>|  <application class="*"><maximized>yes</maximized><position force="yes"><x>0</x><y>0</y></position></application>\n</applications>|' \
    -e 's|</keyboard>|  <keybind key="C-S-d"><action name="ToggleDecorations"/></keybind>\n</keyboard>|' \
    -e 's|<number>4</number>|<number>1</number>|' \
    /etc/xdg/openbox/rc.xml && \
  sed -i \
    's/--startup/--replace --startup/g' \
    /usr/bin/openbox-session && \
  echo "**** st terminfo ****" && \
  tic /usr/share/doc/st/st.info && \
  echo "**** user perms ****" && \
  echo "abc:abc" | chpasswd && \
  usermod -s /bin/bash abc && \
  groupadd sudo && \
  usermod -aG sudo abc && \
  echo '%sudo ALL=(ALL:ALL) NOPASSWD: ALL' >> /etc/sudoers && \
  echo "**** proot-apps ****" && \
  mkdir /proot-apps/ && \
  PAPPS_RELEASE=$(curl -sX GET "https://api.github.com/repos/linuxserver/proot-apps/releases/latest" \
    | jq -r '.tag_name') && \
  curl -L https://github.com/linuxserver/proot-apps/releases/download/${PAPPS_RELEASE}/proot-apps-x86_64.tar.gz \
    | tar -xzf - -C /proot-apps/ && \
  echo "${PAPPS_RELEASE}" > /proot-apps/pversion && \
  echo "**** configure locale ****" && \
  for LOCALE in $(curl -sL https://raw.githubusercontent.com/thelamer/lang-stash/master/langs); do \
    localedef -i $LOCALE -f UTF-8 $LOCALE.UTF-8; \
  done && \
  echo "**** theme ****" && \
  curl -s https://raw.githubusercontent.com/thelamer/lang-stash/master/theme.tar.gz \
    | tar xzvf - -C /usr/share/themes/Clearlooks/openbox-3/

RUN \
  echo "**** package provenance ****" && \
  dnf repoquery --installed --qf '%{name}|%{version}|%{reponame}' | sort > /etc/package_provenance_rhel9.txt && \
  echo "**** cleanup ****" && \
  dnf clean all && \
  rm -rf \
    /tmp/* \
    /var/cache/dnf/*

# add local files
COPY /root /
COPY --from=frontend /buildout /usr/share/selkies

# ports and volumes
EXPOSE 3000 3001
VOLUME /config

ENTRYPOINT ["/init"]
