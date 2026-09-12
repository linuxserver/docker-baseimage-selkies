# syntax=docker/dockerfile:1
FROM lscr.io/linuxserver/xvfb:alpine322 AS xvfb
FROM ghcr.io/linuxserver/baseimage-alpine:3.24 AS frontend

ARG SELKIES_RELEASE=v2.0.0rc0

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
  git checkout -f ${SELKIES_RELEASE}

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
    npm install && \
    npm run build && \
    mkdir -p dist/src && \
    cp ../selkies-web-core/dist/selkies-core.js dist/src/ && \
    cp ../universal-touch-gamepad/universalTouchGamepad.js dist/src/ && \
    mkdir -p /buildout/$DASH && \
    cp -ar dist/* /buildout/$DASH/; \
  done

FROM ghcr.io/linuxserver/baseimage-alpine:3.24 AS wtype

RUN \
  echo "**** wtype build deps ****" && \
  apk add \
    alpine-sdk \
    cmake \
    git \
    wayland-dev \
    libxkbcommon-dev \
    meson \
    ninja-build \
    pkgconf

RUN \
  echo "**** build wtype ****" && \
  cd /tmp && \
  git clone \
    https://github.com/linuxserver/waylandtyper.git && \
  cd waylandtyper && \
  make && \
  mv \
    wtype \
    /usr/bin/wtype

FROM ghcr.io/linuxserver/baseimage-alpine:3.24 AS selkies-desktop

RUN \
  echo "**** selkies-desktop build deps ****" && \
  apk add \
    alpine-sdk \
    git \
    cairo-dev \
    wayland-dev \
    wayland-protocols

RUN \
  echo "**** build selkies-desktop ****" && \
  cd /tmp && \
  git clone \
    https://github.com/selkies-project/selkies-desktop.git && \
  cd selkies-desktop && \
  make && \
  mv \
    selkies-desktop \
    /usr/bin/selkies-desktop

FROM ghcr.io/linuxserver/baseimage-alpine:3.24 AS labwc-builder

RUN \
  echo "**** install labwc/wlroots build deps ****" && \
  apk add --no-cache \
    build-base \
    cairo-dev \
    eudev-dev \
    gettext-dev \
    git \
    glib-dev \
    glslang-dev \
    hwdata-dev \
    libdisplay-info-dev \
    libdrm-dev \
    libinput-dev \
    libliftoff-dev \
    librsvg-dev \
    libsfdo-dev \
    libx11-dev \
    libxcb-dev \
    libxkbcommon-dev \
    libxml2-dev \
    mesa-dev \
    meson \
    ninja \
    pango-dev \
    pixman-dev \
    pkgconf \
    scdoc \
    seatd \
    vulkan-headers \
    vulkan-loader-dev \
    wayland-dev \
    wayland-protocols \
    wlroots0.19-dev \
    xcb-util-errors-dev \
    xcb-util-renderutil-dev \
    xcb-util-wm-dev \
    xwayland-dev

COPY /labwc-ipc.patch /labwc-seam.patch /labwc-screens.patch /

RUN \
  echo "**** build labwc 0.9.7 ****" && \
  git clone https://github.com/labwc/labwc.git /tmp/labwc && \
  cd /tmp/labwc && \
  git checkout 0.9.7 && \
  cp /labwc-ipc.patch labwc-ipc.patch && \
  git apply labwc-ipc.patch && \
  cp /labwc-seam.patch labwc-seam.patch && \
  git apply labwc-seam.patch && \
  cp /labwc-screens.patch labwc-screens.patch && \
  git apply labwc-screens.patch && \
  meson setup build --prefix=/usr --libdir=lib -Dxwayland=enabled -Dnls=enabled && \
  ninja -C build && \
  ninja -C build install

FROM ghcr.io/linuxserver/baseimage-alpine:3.24 AS interposers

ARG SELKIES_RELEASE=v2.0.0rc0

RUN \
  echo "**** interposer build deps ****" && \
  apk add --no-cache \
    build-base \
    git \
    linux-headers

RUN \
  echo "**** ingest selkies addons ****" && \
  git clone \
    https://github.com/selkies-project/selkies.git \
    /src && \
  cd /src && \
  git checkout -f ${SELKIES_RELEASE} && \
  mkdir -p /buildout/usr/lib /buildout/opt/lib && \
  echo "**** build selkies joystick interposer ****" && \
  cd /src/addons/js-interposer && \
  gcc -shared -fPIC -ldl \
    -o /buildout/usr/lib/selkies_joystick_interposer.so \
    joystick_interposer.c && \
  echo "**** build selkies webcam interposer ****" && \
  cd /src/addons/v4l2-interposer && \
  gcc -shared -fPIC -ldl -pthread \
    -o /buildout/usr/lib/selkies_v4l2_interposer.so \
    v4l2_interposer.c && \
  echo "**** build selkies fake udev ****" && \
  cd /src/addons/fake-udev && \
  make && \
  mv \
    libudev.so.1.0.0-fake \
    /buildout/opt/lib/libudev.so.1.0.0-fake

# Runtime stage
FROM ghcr.io/linuxserver/baseimage-alpine:3.24

# set version label
ARG BUILD_DATE
ARG VERSION
ARG SELKIES_RELEASE=v2.0.0rc0
ARG PIXELFLUX_RELEASE=2.1.0rc0
ARG PCMFLUX_RELEASE=2.1.0rc0
LABEL build_version="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="thelamer"

# env
ENV DISPLAY=:1 \
    PERL5LIB=/usr/local/bin \
    HOME=/config \
    START_DOCKER=true \
    PULSE_RUNTIME_PATH=/defaults \
    SELKIES_INTERPOSER=/usr/lib/selkies_joystick_interposer.so \
    SELKIES_WEBCAM_INTERPOSER=/usr/lib/selkies_v4l2_interposer.so \
    DISABLE_ZINK=false \
    DISABLE_DRI3=false \
    SELKIES_ENCODER="h264enc,jpeg" \
    SELKIES_ENABLE_BASIC_AUTH=false \
    SELKIES_VIDEO_STREAMING_MODE=false \
    SELKIES_ALLOWED_ORIGINS="*" \
    SHELL=/bin/bash \
    TITLE=Selkies

RUN \
  echo "**** install build deps ****" && \
  apk add --no-cache --virtual .build-deps \
    alpine-sdk \
    cairo-dev \
    g++ \
    gcc \
    libxkbcommon-dev \
    linux-headers \
    musl-dev \
    python3-dev && \
  echo "**** install runtime deps ****" && \
  apk add --no-cache \
    at-spi2-core \
    bash \
    breeze-cursors \
    ca-certificates \
    cairo \
    cmake \
    dbus-x11 \
    docker \
    docker-cli-compose \
    dunst \
    file \
    font-adobe-100dpi \
    font-adobe-75dpi \
    font-misc-misc \
    font-noto \
    font-noto-cjk \
    font-noto-emoji \
    foot \
    freetype \
    fuse-overlayfs \
    git \
    gnutls \
    gobject-introspection \
    gtk+3.0 \
    intel-media-driver \
    kbd \
    labwc \
    lang \
    libev \
    libfontenc \
    libgcrypt \
    libjpeg-turbo \
    libnotify \
    libtasn1 \
    libx11 \
    libxau \
    libxcb \
    libxcursor \
    libxcvt \
    libxdmcp \
    libxext \
    libxfixes \
    libxfont2 \
    libxinerama \
    libxkbcommon \
    libxkbcommon-x11 \
    libxshmfence \
    libxtst \
    linux-firmware-none \
    linux-pam \
    mesa-dri-gallium \
    mesa-gbm \
    mesa-gl \
    mesa-va-gallium \
    mesa-vulkan-ati \
    mesa-vulkan-intel \
    mesa-vulkan-swrast \
    musl-utils \
    nginx \
    nginx-mod-http-fancyindex \
    nss \
    openbox \
    openssh-client \
    openssl \
    opus \
    p11-kit \
    pciutils \
    procps \
    pulseaudio \
    pulseaudio-utils \
    python3 \
    setxkbmap \
    shadow \
    st \
    sudo \
    tar \
    util-linux \
    vulkan-loader \
    vulkan-tools \
    wayland \
    wl-clipboard \
    wlr-randr \
    wlroots0.19 \
    x264-libs \
    xauth \
    xcb-util-image \
    xcb-util-keysyms \
    xclip \
    xdg-utils \
    xdotool \
    xf86-video-amdgpu \
    xf86-video-ati \
    xf86-video-intel \
    xf86-video-nouveau \
    xf86-video-qxl \
    xfconf \
    xkbcomp \
    xkeyboard-config \
    xorg-server \
    xprop \
    xrandr \
    xrdb \
    xsel \
    xset \
    xsettingsd \
    xterm \
    xvfb \
    zlib \
    zstd && \
  echo "**** install selkies ****" && \
  python3 \
    -m venv \
    --system-site-packages \
    /lsiopy && \
  pip install \
    https://github.com/selkies-project/pixelflux/releases/download/${PIXELFLUX_RELEASE}/pixelflux-${PIXELFLUX_RELEASE}-cp314-cp314-musllinux_1_2_x86_64.whl \
    https://github.com/selkies-project/pcmflux/releases/download/${PCMFLUX_RELEASE}/pcmflux-${PCMFLUX_RELEASE}-cp314-cp314-musllinux_1_2_x86_64.whl \
    https://github.com/selkies-project/selkies/releases/download/${SELKIES_RELEASE}/selkies-${SELKIES_RELEASE#v}-py3-none-any.whl && \
  pip install setuptools && \
  echo "**** install pelorus ****" && \
  mkdir -p /tmp/pelorus && \
  PELORUS_RELEASE=$(curl -sX GET "https://api.github.com/repos/linuxserver/pelorus/releases/latest" \
    | jq -r '.tag_name') && \
  curl -o \
    /tmp/pelorus.tar.gz -L \
    "https://github.com/linuxserver/pelorus/archive/${PELORUS_RELEASE}.tar.gz" && \
  tar xf \
    /tmp/pelorus.tar.gz -C \
    /tmp/pelorus/ --strip-components=1 && \
  pip install /tmp/pelorus && \
  echo "**** add icon ****" && \
  mkdir -p \
    /usr/share/selkies/www && \
  curl -o \
    /usr/share/selkies/www/icon.png \
    https://raw.githubusercontent.com/linuxserver/docker-templates/master/linuxserver.io/img/selkies-logo.png && \
  curl -o \
    /usr/share/selkies/www/favicon.ico \
    https://raw.githubusercontent.com/linuxserver/docker-templates/refs/heads/master/linuxserver.io/img/selkies-icon.ico && \
  echo "**** openbox tweaks ****" && \
  sed -i \
    -e 's/NLIMC/NLMC/g' \
    -e 's|</applications>|  <application class="*"><maximized>yes</maximized></application>\n</applications>|' \
    -e 's|</keyboard>|  <keybind key="C-S-d"><action name="ToggleDecorations"/></keybind>\n</keyboard>|' \
    -e 's|<number>4</number>|<number>1</number>|' \
    /etc/xdg/openbox/rc.xml && \
  sed -i \
    's/--startup/--replace --startup/g' \
    /usr/bin/openbox-session && \
  echo "**** user perms ****" && \
  echo "abc:abc" | chpasswd && \
  usermod -s /bin/bash abc && \
  echo '%wheel ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/wheel && \
  adduser abc wheel && \
  echo "**** proot-apps ****" && \
  mkdir /proot-apps/ && \
  PAPPS_RELEASE=$(curl -sX GET "https://api.github.com/repos/linuxserver/proot-apps/releases/latest" \
    | jq -r '.tag_name') && \
  curl -L https://github.com/linuxserver/proot-apps/releases/download/${PAPPS_RELEASE}/proot-apps-x86_64.tar.gz \
    | tar -xzf - -C /proot-apps/ && \
  echo "${PAPPS_RELEASE}" > /proot-apps/pversion && \
  echo "**** proot-bwrap ****" && \
  PROOT_BWRAP_COMMIT=$(curl -sX GET "https://api.github.com/repos/selkies-project/proot-bwrap/commits/main" \
    | jq -r '.sha') && \
  curl -o \
    /proot-apps/proot-bwrap -L \
    "https://raw.githubusercontent.com/selkies-project/proot-bwrap/${PROOT_BWRAP_COMMIT}/proot-bwrap" && \
  chmod +x /proot-apps/proot-bwrap && \
  echo "**** dind support ****" && \
  addgroup -S dockremap && \
  adduser -S -G dockremap dockremap && \
  echo 'dockremap:165536:65536' >> /etc/subuid && \
  echo 'dockremap:165536:65536' >> /etc/subgid && \
  curl -o \
  /usr/local/bin/dind -L \
    https://raw.githubusercontent.com/moby/moby/master/hack/dind && \
  chmod +x /usr/local/bin/dind && \
  usermod -aG docker abc && \
  echo 'hosts: files dns' > /etc/nsswitch.conf && \
  echo "**** theme ****" && \
  curl -s https://raw.githubusercontent.com/thelamer/lang-stash/master/theme.tar.gz \
    | tar xzvf - -C /usr/share/themes/Clearlooks/openbox-3/ && \
  echo "**** cleanup ****" && \
  apk del .build-deps && \
  rm -rf \
    /config/.cache \
    /tmp/*

# add local files
COPY /root /
COPY --from=frontend /buildout /usr/share/selkies
COPY --from=xvfb / /
COPY --from=wtype /usr/bin/wtype /usr/bin/wtype
COPY --from=selkies-desktop /usr/bin/selkies-desktop /usr/bin/selkies-desktop
COPY --from=interposers /buildout /
COPY --from=labwc-builder /usr/bin/labwc /usr/bin/labwc

# ports and volumes
EXPOSE 3000 3001
VOLUME /config
