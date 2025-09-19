# syntax=docker/dockerfile:1
FROM lscr.io/linuxserver/xvfb:kali AS xvfb
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
  git checkout -f 5e8079aaea2d2c4da2a0ffc477dfd0f2622cb2a7

RUN \
  echo "**** build frontend ****" && \
  cd /src && \
  cd addons/gst-web-core && \
  npm install && \
  npm run build && \
  cp dist/selkies-core.js ../selkies-dashboard/src && \
  cd ../selkies-dashboard && \
  npm install && \
  npm run build && \
  mkdir dist/src dist/nginx && \
  cp ../universal-touch-gamepad/universalTouchGamepad.js dist/src/ && \
  cp ../gst-web-core/nginx/* dist/nginx/ && \
  cp -r ../gst-web-core/dist/jsdb dist/ && \
  mkdir /buildout && \
  cp -ar dist/* /buildout/

# Runtime stage
FROM ghcr.io/linuxserver/baseimage-debian:kali

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
    TITLE=Selkies

RUN \
  echo "**** dev deps ****" && \
  apt-get update && \
  DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
    python3-dev && \
  echo "**** enable locales ****" && \
  rm -f \
    /etc/apt/apt.conf.d/docker-no-languages && \
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
    libev4 \
    libfontenc1 \
    libfreetype6 \
    libgbm1 \
    libgcrypt20 \
    libgirepository-1.0-1 \
    libgl1-mesa-dri \
    libglu1-mesa \
    libgnutls30 \
    libnginx-mod-http-fancyindex \
    libnotify-bin \
    libopus0 \
    libp11-kit0 \
    libpam0g \
    libtasn1-6 \
    libvulkan1 \
    libx11-6 \
    libx264-164 \
    libxau6 \
    libxcb1 \
    libxcursor1 \
    libxdmcp6 \
    libxext6 \
    libxfconf-0-3 \
    libxfixes3 \
    libxfont2 \
    libxinerama1 \
    libxshmfence1 \
    libxtst6 \
    locales-all \
    make \
    mesa-libgallium \
    mesa-va-drivers \
    mesa-vulkan-drivers \
    nginx \
    openbox \
    openssh-client \
    openssl \
    pciutils \
    procps \
    psmisc \
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
  echo "**** install selkies ****" && \
  SELKIES_RELEASE=$(curl -sX GET "https://api.github.com/repos/selkies-project/selkies/releases/latest" \
    | awk '/tag_name/{print $4;exit}' FS='[""]') && \
  curl -o \
    /tmp/selkies.tar.gz -L \
    "https://github.com/selkies-project/selkies/archive/5e8079aaea2d2c4da2a0ffc477dfd0f2622cb2a7.tar.gz" && \
  cd /tmp && \
  tar xf selkies.tar.gz && \
  cd selkies-* && \
  sed -i '/cryptography/d' pyproject.toml && \
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
  apt-get -y remove \
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
COPY --from=frontend /buildout /usr/share/selkies/www
COPY --from=xvfb / /

# ports and volumes
EXPOSE 3000 3001
VOLUME /config
