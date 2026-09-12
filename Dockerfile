# syntax=docker/dockerfile:1
FROM lscr.io/linuxserver/xvfb:arch AS xvfb
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

FROM ghcr.io/linuxserver/baseimage-arch:latest AS wtype

RUN \
  echo "**** wtype build deps ****" && \
  pacman -Sy --noconfirm --needed \
    base-devel \
    cmake \
    git \
    libxkbcommon \
    meson \
    ninja \
    pkgconf \
    wayland

RUN \
  echo "**** build wtype ****" && \
  cd /tmp && \
  git clone \
    https://github.com/linuxserver/waylandtyper.git && \
  cd waylandtyper && \
  make && \
  mv \
    wtype \
    /usr/sbin/wtype

FROM ghcr.io/linuxserver/baseimage-arch:latest AS selkies-desktop

RUN \
  echo "**** selkies-desktop build deps ****" && \
  pacman -Sy --noconfirm \
    base-devel \
    cairo \
    git \
    wayland \
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

FROM ghcr.io/linuxserver/baseimage-arch:latest AS labwc-builder

RUN \
  echo "**** install labwc/wlroots build deps ****" && \
  pacman -Sy --noconfirm \
    base-devel \
    cairo \
    git \
    glib2 \
    glslang \
    hwdata \
    libdisplay-info \
    libdrm \
    libinput \
    libliftoff \
    librsvg \
    libsfdo \
    libx11 \
    libxcb \
    libxkbcommon \
    libxml2 \
    mesa \
    meson \
    ninja \
    pango \
    pixman \
    pkgconf \
    scdoc \
    seatd \
    systemd-libs \
    vulkan-headers \
    vulkan-icd-loader \
    wayland \
    wayland-protocols \
    xcb-util-errors \
    xcb-util-renderutil \
    xcb-util-wm \
    xorg-xwayland

RUN \
  echo "**** build wlroots 0.19.3 ****" && \
  git clone https://gitlab.freedesktop.org/wlroots/wlroots.git /tmp/wlroots && \
  cd /tmp/wlroots && \
  git checkout 0.19.3 && \
  meson setup build --prefix=/usr --libdir=lib -Dxwayland=enabled && \
  ninja -C build && \
  ninja -C build install

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

FROM ghcr.io/linuxserver/baseimage-arch:latest AS interposers

ARG SELKIES_RELEASE=v2.0.0rc0

RUN \
  echo "**** interposer build deps ****" && \
  pacman -Sy --noconfirm --needed \
    base-devel \
    git \
    lib32-gcc-libs \
    lib32-glibc

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
  gcc -m32 -shared -fPIC -ldl \
    -o /buildout/usr/lib/selkies_joystick_interposer_32.so \
    joystick_interposer.c && \
  echo "**** build selkies webcam interposer ****" && \
  cd /src/addons/v4l2-interposer && \
  gcc -shared -fPIC -ldl -pthread \
    -o /buildout/usr/lib/selkies_v4l2_interposer.so \
    v4l2_interposer.c && \
  gcc -m32 -shared -fPIC -ldl -pthread \
    -o /buildout/usr/lib/selkies_v4l2_interposer_32.so \
    v4l2_interposer.c && \
  echo "**** build selkies fake udev ****" && \
  cd /src/addons/fake-udev && \
  make && \
  mv \
    libudev.so.1.0.0-fake \
    /buildout/opt/lib/libudev.so.1.0.0-fake && \
  make clean && \
  make CC="gcc -m32" && \
  mv \
    libudev.so.1.0.0-fake \
    /buildout/opt/lib/libudev.so.1.0.0-fake_32

# Runtime stage
FROM ghcr.io/linuxserver/baseimage-arch:latest

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
    NVIDIA_DRIVER_CAPABILITIES=all \
    DISABLE_ZINK=false \
    DISABLE_DRI3=false \
    LC_ALL=en_US.UTF-8 \
    SELKIES_ENCODER="h264enc,jpeg" \
    SELKIES_ENABLE_BASIC_AUTH=false \
    SELKIES_VIDEO_STREAMING_MODE=false \
    SELKIES_ALLOWED_ORIGINS="*" \
    SHELL=/bin/bash \
    TITLE=Selkies

RUN \
  echo "**** enable locales ****" && \
  sed -i \
    '/locale/d' \
    /etc/pacman.conf && \
  echo "**** install deps ****" && \
  pacman -Sy --noconfirm --needed \
    at-spi2-core \
    base-devel \
    bash \
    ca-certificates \
    cmake \
    dbus \
    docker \
    docker-compose \
    dunst \
    file \
    foot \
    freetype2 \
    fuse-overlayfs \
    git \
    glib2 \
    glibc \
    gnutls \
    gobject-introspection \
    gtk3 \
    inetutils \
    intel-media-driver \
    kbd \
    labwc \
    libev \
    libfontenc \
    libgcrypt \
    libjpeg-turbo \
    libnotify \
    libtasn1 \
    libva-intel-driver \
    libva-mesa-driver \
    libva-utils \
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
    linux-headers \
    mesa \
    nginx \
    noto-fonts \
    noto-fonts-cjk \
    noto-fonts-emoji \
    nss \
    openbox \
    openssh \
    openssl \
    opus \
    p11-kit \
    pam \
    pciutils \
    procps-ng \
    psmisc \
    pulseaudio \
    python \
    python-gobject \
    shadow \
    sudo \
    tar \
    util-linux \
    vulkan-icd-loader \
    vulkan-intel \
    vulkan-radeon \
    vulkan-tools \
    wayland \
    wl-clipboard \
    wlr-randr \
    x264 \
    xcb-util-image \
    xcb-util-keysyms \
    xclip \
    xcursor-themes \
    xdg-utils \
    xdotool \
    xf86-video-amdgpu \
    xf86-video-ati \
    xf86-video-intel \
    xf86-video-nouveau \
    xf86-video-qxl \
    xfconf \
    xkeyboard-config \
    xorg-fonts-100dpi \
    xorg-fonts-75dpi \
    xorg-fonts-misc \
    xorg-font-util \
    xorg-server \
    xorg-server-xvfb \
    xorg-xwayland \
    xorg-xauth \
    xorg-xrandr \
    xorg-xrdb \
    xorg-xset \
    xsel \
    xsettingsd \
    xterm \
    zlib \
    zstd && \
  pacman -Sy --noconfirm \
    glibc && \
  echo "**** user perms ****" && \
  echo "abc:abc" | chpasswd && \
  usermod -s /bin/bash abc && \
  echo 'abc ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/abc && \
  echo "allowed_users=anybody" > /etc/X11/Xwrapper.config && \
  echo "**** aur installs ****" && \
  cd /tmp && \
  git clone https://aur.archlinux.org/nginx-mod-fancyindex.git && \
  chown -R abc:abc nginx-mod-fancyindex && \
  cd nginx-mod-fancyindex && \
  sudo -u abc makepkg -sAci --skipinteg --noconfirm --needed && \
  cd .. && \
  git clone https://aur.archlinux.org/st.git && \
  chown -R abc:abc st && \
  cd st && \
  sudo -u abc makepkg -sAci --skipinteg --noconfirm --needed && \
  echo "**** install selkies ****" && \
  python3 \
    -m venv \
    --system-site-packages \
    /lsiopy && \
  pip install \
    https://github.com/selkies-project/pixelflux/releases/download/${PIXELFLUX_RELEASE}/pixelflux-${PIXELFLUX_RELEASE}-cp314-cp314-manylinux_2_28_x86_64.whl \
    https://github.com/selkies-project/pcmflux/releases/download/${PCMFLUX_RELEASE}/pcmflux-${PCMFLUX_RELEASE}-cp314-cp314-manylinux_2_28_x86_64.whl \
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
  echo "**** steam icon ****" && \
  mkdir -p /usr/share/icons/hicolor/192x192/apps && \
  curl -o \
    /usr/share/icons/hicolor/192x192/apps/steam.png -L \
    "https://raw.githubusercontent.com/linuxserver/docker-templates/master/linuxserver.io/img/steam-logo.png" && \
  echo "**** dind support ****" && \
  groupadd -r dockremap && \
  useradd -r -g dockremap dockremap && \
  echo 'dockremap:165536:65536' >> /etc/subuid && \
  echo 'dockremap:165536:65536' >> /etc/subgid && \
  curl -o \
  /usr/local/bin/dind -L \
    https://raw.githubusercontent.com/moby/moby/master/hack/dind && \
  chmod +x /usr/local/bin/dind && \
  usermod -aG docker abc && \
  echo "**** configure locale and nginx ****" && \
  for LOCALE in $(curl -sL https://raw.githubusercontent.com/thelamer/lang-stash/master/langs); do \
    localedef -i $LOCALE -f UTF-8 $LOCALE.UTF-8; \
  done && \
  sed -i '$d' /etc/nginx/nginx.conf && \
  echo "include /etc/nginx/conf.d/*;}" >> /etc/nginx/nginx.conf && \
  mkdir -p /etc/nginx/conf.d && \
  echo "load_module /usr/lib/nginx/modules/ngx_http_fancyindex_module.so;" > \
    /etc/nginx/modules.d/fancy.conf && \
  echo "**** theme ****" && \
  curl -s https://raw.githubusercontent.com/thelamer/lang-stash/master/theme.tar.gz \
    | tar xzvf - -C /usr/share/themes/Clearlooks/openbox-3/ && \
  echo "**** cleanup ****" && \
  pacman -Rn --noconfirm linux-headers && \
  pacman -Rsn --noconfirm \
    git \
    $(pacman -Qdtq) && \
  rm -rf \
    /config/.cache \
    /tmp/* \
    /var/cache/pacman/pkg/* \
    /var/lib/pacman/sync/*

# add local files
COPY /root /
COPY --from=frontend /buildout /usr/share/selkies
COPY --from=xvfb / /
COPY --from=wtype /usr/sbin/wtype /usr/sbin/wtype
COPY --from=selkies-desktop /usr/bin/selkies-desktop /usr/bin/selkies-desktop
COPY --from=interposers /buildout /
COPY --from=labwc-builder /usr/bin/labwc /usr/bin/labwc
COPY --from=labwc-builder /usr/lib/libwlroots-0.19.so* /usr/lib/

# ports and volumes
EXPOSE 3000 3001
VOLUME /config
