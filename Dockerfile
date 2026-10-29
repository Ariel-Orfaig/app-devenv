# syntax=docker/dockerfile:1
#
# Cross-platform mobile development environment (Android + iOS tooling)
# with Claude Code CLI built in.
#
#   - Android: JDK, Android SDK (cmdline-tools, platform-tools, platforms,
#     build-tools, cmake), optional NDK and emulator
#   - Flutter / Dart
#   - React Native / Expo (Node.js LTS, yarn/pnpm via corepack, EAS CLI)
#   - Ruby + Bundler (fastlane)
#   - Claude Code CLI
#
# iOS apps can't be compiled on Linux (Xcode only runs on macOS). This image
# covers writing, testing and linting the iOS side; for iOS binaries use a
# cloud macOS builder (EAS Build, Codemagic, GitHub Actions macOS runners...).
# See README.md.

FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive

# ---- Versions (override with --build-arg) ---------------------------------
ARG JAVA_VERSION=17
ARG NODE_MAJOR=24
ARG ANDROID_CMDLINE_TOOLS_BUILD=13114758
ARG ANDROID_PLATFORM=android-36
ARG ANDROID_BUILD_TOOLS=36.0.0
ARG ANDROID_CMAKE=3.22.1
# Leave empty to skip; Gradle downloads the NDK a project needs on first build.
ARG ANDROID_NDK=
# Set to "true" to install the emulator + a system image (needs /dev/kvm at run time).
ARG INSTALL_EMULATOR=false
ARG ANDROID_SYSTEM_IMAGE="system-images;android-36;google_apis;x86_64"
ARG FLUTTER_VERSION=3.47.9
ARG CLAUDE_CODE_VERSION=latest

# ---- Container user (match your host UID/GID to avoid permission issues) --
ARG USERNAME=dev
ARG USER_UID=1000
ARG USER_GID=1000

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TZ=Etc/UTC

# ---- Base OS packages -----------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
        bash-completion build-essential ca-certificates clang cmake curl file \
        git git-lfs gnupg htop jq less libglu1-mesa libgtk-3-dev liblzma-dev \
        libstdc++-12-dev locales nano ninja-build openssh-client pkg-config \
        python3 python3-pip python3-venv ripgrep rsync ruby-full sudo tmux \
        unzip usbutils vim wget xz-utils zip zlib1g-dev \
        openjdk-${JAVA_VERSION}-jdk-headless \
    && rm -rf /var/lib/apt/lists/*

# ---- Node.js LTS + package managers + mobile CLIs + Claude Code -----------
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR}.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/* \
    && corepack enable \
    && npm install -g \
        eas-cli \
        "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}" \
    && npm cache clean --force

# fastlane / CocoaPods-style Ruby tooling is installed per project via Bundler.
RUN gem install bundler --no-document

# ---- Non-root user (Claude Code refuses some modes as root) ---------------
# ubuntu:24.04 ships a default "ubuntu" user with UID/GID 1000; remove it so
# our user can take that UID.
RUN if id ubuntu >/dev/null 2>&1; then userdel -r ubuntu; fi \
    && groupadd --gid ${USER_GID} ${USERNAME} \
    && useradd --uid ${USER_UID} --gid ${USER_GID} -m -s /bin/bash ${USERNAME} \
    && groupadd -f plugdev && groupadd -f kvm \
    && usermod -aG plugdev,kvm ${USERNAME} \
    && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} \
    && chmod 0440 /etc/sudoers.d/${USERNAME}

# ---- Android SDK ----------------------------------------------------------
ENV JAVA_HOME=/opt/java \
    ANDROID_HOME=/opt/android-sdk \
    ANDROID_SDK_ROOT=/opt/android-sdk
ENV PATH=${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools:${ANDROID_HOME}/emulator:${PATH}

RUN ln -s /usr/lib/jvm/java-${JAVA_VERSION}-openjdk-* ${JAVA_HOME} \
    && mkdir -p ${ANDROID_HOME}/cmdline-tools \
    && curl -fsSL -o /tmp/cmdline-tools.zip \
        "https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_CMDLINE_TOOLS_BUILD}_latest.zip" \
    && unzip -q /tmp/cmdline-tools.zip -d /tmp/cmdline-tools \
    && mv /tmp/cmdline-tools/cmdline-tools ${ANDROID_HOME}/cmdline-tools/latest \
    && rm -rf /tmp/cmdline-tools /tmp/cmdline-tools.zip \
    && yes | sdkmanager --licenses >/dev/null \
    && sdkmanager --install \
        "platform-tools" \
        "platforms;${ANDROID_PLATFORM}" \
        "build-tools;${ANDROID_BUILD_TOOLS}" \
        "cmake;${ANDROID_CMAKE}" \
    && if [ -n "${ANDROID_NDK}" ]; then sdkmanager --install "ndk;${ANDROID_NDK}"; fi \
    && if [ "${INSTALL_EMULATOR}" = "true" ]; then \
         sdkmanager --install "emulator" "${ANDROID_SYSTEM_IMAGE}"; \
       fi \
    # Let the dev user (and Gradle) install extra SDK packages on demand.
    && chown -R ${USER_UID}:${USER_GID} ${ANDROID_HOME}

# ---- Flutter --------------------------------------------------------------
ENV FLUTTER_HOME=/opt/flutter
ENV PATH=${FLUTTER_HOME}/bin:${PATH}

RUN git clone --depth 1 --branch ${FLUTTER_VERSION} https://github.com/flutter/flutter.git ${FLUTTER_HOME} \
    && chown -R ${USER_UID}:${USER_GID} ${FLUTTER_HOME}

# ---- Per-user setup -------------------------------------------------------
USER ${USERNAME}
WORKDIR /home/${USERNAME}

RUN git config --global --add safe.directory '*' \
    && flutter config --no-analytics --android-sdk ${ANDROID_HOME} \
    && dart --disable-analytics \
    && flutter precache --android --linux --web \
    && (yes | flutter doctor --android-licenses >/dev/null 2>&1 || true)

# Gradle/npm/pub caches and Claude Code config live in volumes (see compose).
ENV GRADLE_USER_HOME=/home/${USERNAME}/.gradle \
    PUB_CACHE=/home/${USERNAME}/.pub-cache \
    CLAUDE_CONFIG_DIR=/home/${USERNAME}/.claude \
    DISABLE_AUTOUPDATER=1 \
    NPM_CONFIG_PREFIX=/home/${USERNAME}/.npm-global \
    REACT_NATIVE_PACKAGER_HOSTNAME=localhost
ENV PATH=/home/${USERNAME}/.npm-global/bin:${PUB_CACHE}/bin:${PATH}

RUN mkdir -p ${GRADLE_USER_HOME} ${PUB_CACHE} ${CLAUDE_CONFIG_DIR} ${NPM_CONFIG_PREFIX} \
        /home/${USERNAME}/.npm /home/${USERNAME}/.android \
    # ADB_HOST_SERVER=host:port -> use the adb server running on the host
    && echo '[ -n "$ADB_HOST_SERVER" ] && export ADB_SERVER_SOCKET="tcp:$ADB_HOST_SERVER"' >> /home/${USERNAME}/.bashrc

COPY --chown=${USERNAME}:${USERNAME} config/CLAUDE.md /opt/devenv/CLAUDE.md
COPY --chown=${USERNAME}:${USERNAME} config/claude-settings.json /opt/devenv/claude-settings.json
COPY --chmod=0755 scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY --chmod=0755 scripts/devenv-doctor.sh /usr/local/bin/devenv-doctor

WORKDIR /workspace

# Metro / Expo, Flutter web, Android debug bridge forwarding
EXPOSE 8081 19000 19001 19002 8080

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["bash", "-l"]
