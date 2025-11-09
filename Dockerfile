# syntax=docker/dockerfile:1
FROM lscr.io/linuxserver/xvfb:debianbookworm AS xvfb
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
  git checkout -f db030a319f6e60994ec1be23217506ddab56ac5f

RUN \
  echo "**** build shared core library ****" && \
  cd /src/addons/gst-web-core && \
  npm install && \
  npm run build && \
  echo "**** build multiple dashboards ****" && \
  DASHBOARDS="selkies-dashboard selkies-dashboard-zinc selkies-dashboard-wish" && \
  mkdir /buildout && \
  for DASH in $DASHBOARDS; do \
    cd /src/addons/$DASH && \
    cp ../gst-web-core/dist/selkies-core.js src/ && \
    npm install && \
    npm run build && \
    mkdir -p dist/src dist/nginx && \
    cp ../gst-web-core/dist/selkies-core.js dist/src/ && \
    cp ../universal-touch-gamepad/universalTouchGamepad.js dist/src/ && \
    cp ../gst-web-core/nginx/* dist/nginx/ && \
    cp -r ../gst-web-core/dist/jsdb dist/ && \
    mkdir -p /buildout/$DASH && \
    cp -ar dist/* /buildout/$DASH/; \
  done

# Runtime stage
FROM ghcr.io/linuxserver/baseimage-debian:bookworm

# set version label
ARG BUILD_DATE
ARG VERSION
LABEL build_version="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="thelamer"

# env
ENV DISPLAY=:1 \
    PERL5LIB=/usr/local/bin \
    HOME=/config \
    START_DOCKER=true \
    PULSE_RUNTIME_PATH=/defaults \
    SELKIES_INTERPOSER=/usr/lib/selkies_joystick_interposer.so \
    NVIDIA_DRIVER_CAPABILITIES=all \
    DISABLE_ZINK=false \
    DISABLE_DRI3=false \
    TITLE=Selkies

RUN \
  echo "**** dev deps ****" && \
  apt-get update && \
  DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
    python3-dev && \
  echo "**** enable locales ****" && \
  sed -i \
    '/locale/d' \
    /etc/dpkg/dpkg.cfg.d/docker && \
  echo "**** install deps ****" && \
  curl -fsSL https://download.docker.com/linux/debian/gpg | tee /usr/share/keyrings/docker.asc >/dev/null && \
  echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker.asc] https://download.docker.com/linux/debian bookworm stable" > /etc/apt/sources.list.d/docker.list && \
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
  apt-get update && \
  DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
    breeze-cursor-theme \
    ca-certificates \
    cmake \
    console-data \
    containerd.io \
    dbus-x11 \
    docker-buildx-plugin \
    docker-ce \
    docker-ce-cli \
    docker-compose-plugin \
    dunst \
    file \
    firmware-linux-nonfree \
    firmware-misc-nonfree \
    fonts-noto-cjk \
    fonts-noto-color-emoji \
    fonts-noto-core \
    fuse-overlayfs \
    g++ \
    gcc \
    git \
    intel-media-va-driver \
    kbd \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libev4 \
    libfontenc1 \
    libfreetype6 \
    libgbm1 \
    libgcrypt20 \
    libgirepository-1.0-1 \
    libgl1-mesa-dri \
    libglu1-mesa \
    libgnutls30 \
    libgtk-3.0 \
    libnginx-mod-http-fancyindex \
    libnotify-bin \
    libnss3 \
    libopus0 \
    libp11-kit0 \
    libpam0g \
    libtasn1-6 \
    libvulkan1 \
    libx11-6 \
    libxau6 \
    libxcb1 \
    libxcb-icccm4 \
    libxcb-image0 \
    libxcb-keysyms1 \
    libxcb-render-util0 \
    libxcursor1 \
    libxdmcp6 \
    libxext6 \
    libxfconf-0-3 \
    libxfixes3 \
    libxfont2 \
    libxinerama1 \
    libxkbcommon-x11-0 \
    libxshmfence1 \
    libxtst6 \
    locales-all \
    make \
    mesa-va-drivers \
    mesa-vulkan-drivers \
    nginx \
    openbox \
    openssh-client \
    openssl \
    pciutils \
    procps \
    pulseaudio \
    pulseaudio-utils \
    python3 \
    python3-venv \
    software-properties-common \
    ssl-cert \
    stterm \
    sudo \
    tar \
    util-linux \
    vulkan-tools \
    x11-apps \
    x11-common \
    x11-utils \
    x11-xkb-utils \
    x11-xserver-utils \
    xauth \
    xclip \
    xcvt \
    xdg-utils \
    xdotool \
    xfconf \
    xfonts-base \
    xkb-data \
    xsel \
    xserver-common \
    xserver-xorg-core \
    xserver-xorg-video-amdgpu \
    xserver-xorg-video-ati \
    xserver-xorg-video-intel \
    xserver-xorg-video-nouveau \
    xserver-xorg-video-qxl \
    xsettingsd \
    xterm \
    xutils \
    xvfb \
    zlib1g && \
  apt install -t bookworm-backports -y \
    mesa-libgallium && \
  echo "**** install selkies ****" && \
  SELKIES_RELEASE=$(curl -sX GET "https://api.github.com/repos/selkies-project/selkies/releases/latest" \
    | awk '/tag_name/{print $4;exit}' FS='[""]') && \
  curl -o \
    /tmp/selkies.tar.gz -L \
    "https://github.com/selkies-project/selkies/archive/db030a319f6e60994ec1be23217506ddab56ac5f.tar.gz" && \
  cd /tmp && \
  tar xf selkies.tar.gz && \
  cd selkies-* && \
  python3 \
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
    https://raw.githubusercontent.com/linuxserver/docker-templates/refs/heads/master/linuxserver.io/img/selkies-icon.ico && \
  echo "**** openbox tweaks ****" && \
  sed -i \
    -e 's/NLIMC/NLMC/g' \
    -e '/debian-menu/d' \
    -e 's|</applications>|  <application class="*"><maximized>yes</maximized></application>\n</applications>|' \
    -e 's|</keyboard>|  <keybind key="C-S-d"><action name="ToggleDecorations"/></keybind>\n</keyboard>|' \
    -e 's|<number>4</number>|<number>1</number>|' \
    /etc/xdg/openbox/rc.xml && \
  sed -i \
    's/--startup/--replace --startup/g' \
    /usr/bin/openbox-session && \
  echo "**** user perms ****" && \
  sed -e 's/%sudo	ALL=(ALL:ALL) ALL/%sudo ALL=(ALL:ALL) NOPASSWD: ALL/g' \
    -i /etc/sudoers && \
  echo "abc:abc" | chpasswd && \
  usermod -s /bin/bash abc && \
  usermod -aG sudo abc && \
  echo "**** proot-apps ****" && \
  mkdir /proot-apps/ && \
  PAPPS_RELEASE=$(curl -sX GET "https://api.github.com/repos/linuxserver/proot-apps/releases/latest" \
    | awk '/tag_name/{print $4;exit}' FS='[""]') && \
  curl -L https://github.com/linuxserver/proot-apps/releases/download/${PAPPS_RELEASE}/proot-apps-x86_64.tar.gz \
    | tar -xzf - -C /proot-apps/ && \
  echo "${PAPPS_RELEASE}" > /proot-apps/pversion && \
  echo "**** dind support ****" && \
  useradd -U dockremap && \
  usermod -G dockremap dockremap && \
  echo 'dockremap:165536:65536' >> /etc/subuid && \
  echo 'dockremap:165536:65536' >> /etc/subgid && \
  curl -o \
  /usr/local/bin/dind -L \
    https://raw.githubusercontent.com/moby/moby/master/hack/dind && \
  chmod +x /usr/local/bin/dind && \
  echo 'hosts: files dns' > /etc/nsswitch.conf && \
  usermod -aG docker abc && \
  echo "**** locales ****" && \
  for LOCALE in $(curl -sL https://raw.githubusercontent.com/thelamer/lang-stash/master/langs); do \
    localedef -i $LOCALE -f UTF-8 $LOCALE.UTF-8; \
  done && \
  echo "**** theme ****" && \
  curl -s https://raw.githubusercontent.com/thelamer/lang-stash/master/theme.tar.gz \
    | tar xzvf - -C /usr/share/themes/Clearlooks/openbox-3/ && \
  echo "**** cleanup ****" && \
  apt-get purge -y --autoremove \
    python3-dev && \
  apt-get autoclean && \
  rm -rf \
    /config/.cache \
    /config/.npm \
    /var/lib/apt/lists/* \
    /var/tmp/* \
    /tmp/*

# add local files
COPY /root /
COPY --from=frontend /buildout /usr/share/selkies
COPY --from=xvfb / /

# ports and volumes
EXPOSE 3000 3001
VOLUME /config
