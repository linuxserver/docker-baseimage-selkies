# syntax=docker/dockerfile:1
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
  git checkout -f 159656dfb3f045bf6e041042140bafaf1bbd9c61

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
FROM ghcr.io/linuxserver/baseimage-el:9

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
  echo "**** install build deps ****" && \
  dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo && \
  dnf install -y \
    gcc \
    gcc-c++ \
    glibc-devel \
    kernel-headers \
    make \
    python3-devel && \
  echo "**** install runtime deps ****" && \
  dnf install -y --setopt=install_weak_deps=False --best \
    bash \
    breeze-cursor-theme \
    ca-certificates \
    cmake \
    containerd.io \
    dbus-x11 \
    docker-buildx-plugin \
    docker-ce \
    docker-ce-cli \
    docker-compose-plugin \
    file \
    freetype \
    fuse-overlayfs \
    git \
    glibc-all-langpacks \
    glibc-locale-source \
    gnutls \
    google-noto-cjk-fonts-common \
    google-noto-emoji-fonts \
    google-noto-sans-fonts \
    intel-media-driver \
    kbd \
    libdrm \
    libev \
    libfontenc \
    libgcrypt \
    libjpeg-turbo \
    libnotify \
    libtasn1 \
    libva \
    libX11 \
    libXau \
    libxcb \
    libXcursor \
    libxcvt \
    libXdmcp \
    libXext \
    libXfixes \
    libXfont2 \
    libXinerama \
    libxkbcommon-devel \
    libxshmfence \
    libXtst \
    mesa-libgbm \
    mesa-libGL \
    mesa-vulkan-drivers \
    nginx \
    nginx-mod-fancyindex \
    openbox \
    openssh-clients \
    openssl \
    opus \
    p11-kit \
    pam \
    pciutils \
    procps-ng \
    psmisc \
    pulseaudio \
    pulseaudio-libs \
    pulseaudio-utils \
    python3 \
    python3-virtualenv \
    shadow-utils \
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
    xfconf \
    xkeyboard-config \
    xorg-x11-drv-dummy \
    xorg-x11-fonts-100dpi \
    xorg-x11-fonts-75dpi \
    xorg-x11-fonts-misc \
    xorg-x11-font-utils \
    xorg-x11-server-Xorg \
    xorg-x11-server-Xvfb \
    xrandr \
    xrdb \
    xsel \
    xsettingsd \
    xterm \
    zlib && \
  echo "**** install selkies ****" && \
  curl -o \
    /tmp/selkies.tar.gz -L \
    "https://github.com/selkies-project/selkies/archive/159656dfb3f045bf6e041042140bafaf1bbd9c61.tar.gz" && \
  cd /tmp && \
  tar xf selkies.tar.gz && \
  cd selkies-* && \
  sed -i '/cryptography/d' pyproject.toml && \
  sed -i 's/xkbcommon/xkbcommon<1.5/g' pyproject.toml && \
  python3 \
    -m venv \
    /lsiopy && \
  pip install . && \
  pip install setuptools pixelflux==1.4.7 && \
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
    -e 's|<number>4</number>|<number>1</number>|' \
    /etc/xdg/openbox/rc.xml && \
  sed -i \
    's/--startup/--replace --startup/g' \
    /usr/bin/openbox-session && \
  echo "**** user perms ****" && \
  echo "abc:abc" | chpasswd && \
  usermod -s /bin/bash abc && \
  echo '%wheel ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/wheel && \
  usermod -G wheel abc && \
  echo "**** proot-apps ****" && \
  mkdir /proot-apps/ && \
  PAPPS_RELEASE=$(curl -sX GET "https://api.github.com/repos/linuxserver/proot-apps/releases/latest" \
    | awk '/tag_name/{print $4;exit}' FS='[""]') && \
  curl -L https://github.com/linuxserver/proot-apps/releases/download/${PAPPS_RELEASE}/proot-apps-x86_64.tar.gz \
    | tar -xzf - -C /proot-apps/ && \
  echo "${PAPPS_RELEASE}" > /proot-apps/pversion && \
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
  echo "**** configure locale ****" && \
  for LOCALE in $(curl -sL https://raw.githubusercontent.com/thelamer/lang-stash/master/langs); do \
    localedef -i $LOCALE -f UTF-8 $LOCALE.UTF-8; \
  done && \
  echo "**** theme ****" && \
  curl -s https://raw.githubusercontent.com/thelamer/lang-stash/master/theme.tar.gz \
    | tar xzvf - -C /usr/share/themes/Clearlooks/openbox-3/ && \
  echo "**** cleanup ****" && \
  dnf remove -y \
    glibc-devel \
    kernel-headers \
    python3-devel && \
  dnf autoremove -y && \
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
