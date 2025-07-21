# syntax=docker/dockerfile:1
FROM lscr.io/linuxserver/xvfb:alpine322 AS xvfb
FROM ghcr.io/linuxserver/baseimage-alpine:3.22 AS frontend

RUN \
  echo "**** install build packages ****" && \
  apk add --no-cache \
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
  git checkout -f f56d4a951acbcaf659867561f3f659555dfc0cd7

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
  mkdir /buildout && \
  cp -ar dist/* /buildout/


# Runtime stage
FROM ghcr.io/linuxserver/baseimage-alpine:3.22

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
    DISABLE_ZINK=false \
    TITLE=Selkies

RUN \
  echo "**** install build deps ****" && \
  apk add --no-cache --virtual .build-deps \
    alpine-sdk \
    linux-headers \
    musl-dev \
    opus-dev \
    pulseaudio-dev \
    py3-pip \
    py3-setuptools \
    py3-wheel \
    python3-dev && \
  echo "**** install runtime deps ****" && \
  apk add --no-cache \
    bash \
    breeze-cursors \
    ca-certificates \
    cmake \
    kbd \
    docker \
    docker-cli-compose \
    dbus-x11 \
    dunst \
    file \
    linux-firmware-none \
    font-noto-cjk \
    font-noto-emoji \
    font-noto \
    fuse-overlayfs \
    git \
    intel-media-driver \
    libev \
    libfontenc \
    freetype \
    mesa-gbm \
    libgcrypt \
    gobject-introspection \
    mesa-dri-gallium \
    mesa-gl \
    gnutls \
    libjpeg-turbo \
    nginx-mod-http-fancyindex \
    libnotify \
    p11-kit \
    linux-pam \
    libtasn1 \
    vulkan-loader \
    libx11 \
    x264-libs \
    libxau \
    libxcb \
    libxcursor \
    libxdmcp \
    libxext \
    xfconf \
    libxfixes \
    libxfont2 \
    libxinerama \
    libxshmfence \
    libxtst \
    lang \
    musl-utils \
    mesa-va-gallium \
    mesa-vulkan-intel \
    mesa-vulkan-ati \
    mesa-vulkan-swrast \
    nginx \
    openbox \
    openssh-client \
    openssl \
    opus \
    pciutils \
    procps \
    pulseaudio \
    pulseaudio-utils \
    python3 \
    py3-setuptools \
    st \
    sudo \
    shadow \
    tar \
    util-linux \
    vulkan-tools \
    xprop \
    xrdb \
    xset \
    setxkbmap \
    xkbcomp \
    xrandr \
    xauth \
    libxcvt \
    xdg-utils \
    xdotool \
    font-misc-misc \
    font-adobe-100dpi \
    font-adobe-75dpi \
    xkeyboard-config \
    xsel \
    xorg-server \
    xf86-video-amdgpu \
    xf86-video-ati \
    xf86-video-intel \
    xf86-video-nouveau \
    xf86-video-qxl \
    xterm \
    xvfb \
    zlib  && \
  echo "**** install selkies ****" && \
  pip3 install pixelflux pcmflux --break-system-packages && \
  curl -o \
    /tmp/selkies.tar.gz -L \
    "https://github.com/selkies-project/selkies/archive/f56d4a951acbcaf659867561f3f659555dfc0cd7.tar.gz" && \
  cd /tmp && \
  tar xf selkies.tar.gz && \
  cd selkies-* && \
  pip3 install . --break-system-packages && \
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
    -e 's|</applications>|  <application class="*"><maximized>yes</maximized><position force="yes"><x>0</x><y>0</y></position></application>\n</applications>|' \
    -e 's|</keyboard>|  <keybind key="C-S-d"><action name="ToggleDecorations"/></keybind>\n</keyboard>|' \
    /etc/xdg/openbox/rc.xml && \
  echo "**** user perms ****" && \
  echo "abc:abc" | chpasswd && \
  usermod -s /bin/bash abc && \
  echo '%wheel ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/wheel && \
  adduser abc wheel && \
  echo "**** proot-apps ****" && \
  mkdir /proot-apps/ && \
  PAPPS_RELEASE=$(curl -sX GET "https://api.github.com/repos/linuxserver/proot-apps/releases/latest" \
    | awk '/tag_name/{print $4;exit}' FS='[""]') && \
  curl -L https://github.com/linuxserver/proot-apps/releases/download/${PAPPS_RELEASE}/proot-apps-x86_64.tar.gz \
    | tar -xzf - -C /proot-apps/ && \
  echo "${PAPPS_RELEASE}" > /proot-apps/pversion && \
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
COPY --from=frontend /buildout /usr/share/selkies/www
COPY --from=xvfb / /

# ports and volumes
EXPOSE 3000 3001
VOLUME /config
