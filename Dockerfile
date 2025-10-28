# syntax=docker/dockerfile:1
FROM lscr.io/linuxserver/xvfb:alpine322 AS xvfb
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
  git checkout -f 3a7d4d4ee868c85af205d786455ece6a2d4a8935

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
    DISABLE_DRI3=false \
    TITLE=Selkies

RUN \
  echo "**** install build deps ****" && \
  apk add --no-cache --virtual .build-deps \
    alpine-sdk \
    linux-headers \
    musl-dev \
    python3-dev && \
  echo "**** install runtime deps ****" && \
  apk add --no-cache \
    bash \
    breeze-cursors \
    ca-certificates \
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
    freetype \
    fuse-overlayfs \
    git \
    gnutls \
    gobject-introspection \
    intel-media-driver \
    kbd \
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
    x264-libs \
    xauth \
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
    zlib  && \
  echo "**** install selkies ****" && \
  curl -o \
    /tmp/selkies.tar.gz -L \
    "https://github.com/selkies-project/selkies/archive/3a7d4d4ee868c85af205d786455ece6a2d4a8935.tar.gz" && \
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
COPY --from=frontend /buildout /usr/share/selkies
COPY --from=xvfb / /

# ports and volumes
EXPOSE 3000 3001
VOLUME /config
