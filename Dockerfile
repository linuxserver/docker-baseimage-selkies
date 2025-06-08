# syntax=docker/dockerfile:1
FROM ghcr.io/linuxserver/baseimage-alpine:3.21 AS frontend

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
  git checkout -f 4cc4384fcf7849f448905e1ffc4fa48b987d131b

RUN \
  echo "**** build frontend ****" && \
  cd /src && \
  cd addons/gst-web-core && \
  npm install && \
  npm run build && \
  cd ../selkies-dashboard && \
  npm install && \
  npm run build && \
  mkdir dist/src dist/nginx && \
  cp ../gst-web-core/dist/selkies-core.js dist/src/ && \
  cp ../universal-touch-gamepad/universalTouchGamepad.js dist/src/ && \
  cp ../gst-web-core/nginx/* dist/nginx/ && \
  mkdir /buildout && \
  cp -ar dist/* /buildout/


# Runtime stage
FROM ghcr.io/linuxserver/baseimage-arch:latest

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
  echo "**** enable locales ****" && \
  sed -i \
    '/locale/d' \
    /etc/pacman.conf && \
  echo "**** install deps ****" && \
  pacman -Sy --noconfirm --needed \
    amdvlk \
    base-devel \
    bash \
    ca-certificates \
    cmake \
    dbus \
    docker \
    docker-compose \
    dunst \
    file \
    freetype2 \
    git \
    glibc \
    gnutls \
    gobject-introspection \
    gst-plugins-bad \
    gst-plugins-base \
    gst-plugins-good \
    gst-plugins-ugly \
    gst-python \
    gstreamer \
    inetutils \
    intel-media-driver \
    kbd \
    libev \
    libev \
    libfontenc \
    libgcrypt \
    libjpeg-turbo \
    libjpeg-turbo \
    libnotify \
    libtasn1 \
    libva-mesa-driver \
    libx11 \
    libx11 \
    libxau \
    libxcb \
    libxcursor \
    libxcvt \
    libxdmcp \
    libxext \
    libxext \
    libxfixes \
    libxfont2 \
    libxinerama \
    libxshmfence \
    libxtst \
    linux-headers \
    mesa \
    nginx \
    noto-fonts \
    noto-fonts-cjk \
    noto-fonts-emoji \
    openbox \
    openssh \
    openssl \
    p11-kit \
    pam \
    pciutils \
    procps-ng \
    pulseaudio \
    python \
    python \
    python-gobject \
    python-pip \
    python-setuptools \
    python-setuptools \
    python-wheel \
    shadow \
    sudo \
    tar \
    util-linux \
    vulkan-icd-loader \
    vulkan-intel \
    vulkan-radeon \
    vulkan-tools \
    x264 \
    x264 \
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
    xorg-xauth \
    xorg-xrandr \
    xsel \
    xterm \
    zlib && \
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
  pip3 install pixelflux --break-system-packages && \
  curl -o \
    /tmp/selkies.tar.gz -L \
    "https://github.com/selkies-project/selkies/archive/4cc4384fcf7849f448905e1ffc4fa48b987d131b.tar.gz" && \
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
  mv \
    libudev.so.1.0.0-fake \
    /usr/lib/ && \
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
COPY --from=frontend /buildout /usr/share/selkies/www

# ports and volumes
EXPOSE 3000 3001
VOLUME /config
