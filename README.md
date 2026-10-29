# app-devenv — mobile dev container with Claude Code

A Linux Docker environment for cross-platform phone app development
(Android + iOS), with the **Claude Code CLI** installed and set up to use
the toolchain.

| Area | What's inside |
|---|---|
| Android | OpenJDK 17, Android SDK cmdline-tools, platform-tools (`adb`), `platforms;android-36`, `build-tools;36.0.0`, cmake. NDK and emulator are optional. |
| Flutter | Flutter stable `3.47.9` + Dart, Android/Linux/web artifacts precached |
| React Native / Expo | Node.js 24 LTS, npm, yarn + pnpm (corepack), `eas-cli` |
| Release tooling | Ruby + Bundler (install fastlane per project) |
| AI | Claude Code CLI (`claude`), with a `CLAUDE.md` describing this environment and safe default permissions |
| Misc | git, git-lfs, build-essential, clang/ninja/GTK (Flutter Linux desktop), ripgrep, jq, tmux, vim |

## About iOS

Apple's iOS toolchain (Xcode, the iOS SDK, the Simulator, code signing) only
runs on macOS, so **no Linux container can compile or run an iOS app**. What you
can do here:

- Write all the shared code (Dart / JS / TS) and the iOS-specific code and config.
- Run unit tests, linters and analyzers.
- Build iOS binaries **in the cloud** from inside the container:
  - **Expo / React Native:** `eas build -p ios` (set `EXPO_TOKEN` in `.env`)
  - **Flutter or native:** GitHub Actions `macos-latest` runners, Codemagic, Bitrise
- Test on a real iPhone using the cloud build (TestFlight / an internal distribution build).

Android works fully: build, install on a device and debug.

## Quick start

Requirements: Docker with Compose v2 (Docker Desktop on macOS/Windows, or Docker Engine on Linux).

```bash
git clone <this repo> app-devenv && cd app-devenv
```

```bash
make build      # creates .env from .env.example (with your UID/GID) and builds the image (~10 GB, takes a while)
```

```bash
make shell      # starts the container and opens a shell in /workspace
```

Without `make`:

```bash
cp .env.example .env
```

```bash
docker compose up -d --build
```

```bash
docker compose exec mobile-dev bash -l
```

Put your projects in `./workspace` (or point `PROJECTS_DIR` in `.env` at
another folder). They show up at `/workspace` in the container.

On Apple Silicon Macs the image runs as `linux/amd64` under emulation, because Google
ships Android build-tools for x86_64 Linux only. It works, just slower.

## Using Claude Code

```bash
make claude     # or, inside the container: cd /workspace/my-app && claude
```

Sign in one of two ways:
- **Claude subscription / Console login:** run `claude` and follow `/login`. The
  login is saved in the `claude-config` volume, so it lasts across container restarts.
- **API key:** set `ANTHROPIC_API_KEY` in `.env`.

On first start the container copies two files into `~/.claude` (only if they
don't exist yet, so your own edits are kept):

- `config/CLAUDE.md` → `~/.claude/CLAUDE.md` tells Claude what's installed, what it
  can't do (no Xcode, no GUI), and how to reach devices.
- `config/claude-settings.json` → `~/.claude/settings.json` pre-approves safe
  commands (`flutter test`, `./gradlew`, `npm run`, `adb logcat`, …) and blocks
  reading `.env`, keystores and `key.properties`.

Add project-specific instructions with a `CLAUDE.md` in each project's root, as usual.

Claude Code auto-update is turned off in the image. To update it, rebuild:
`docker compose build --no-cache` or pin a version with `CLAUDE_CODE_VERSION` in `.env`.

## Running on a real Android device

Choose one of these:

**A. Use the adb server on your host (works on any OS)**: the phone stays plugged into the host.

```bash
adb kill-server && adb -a nodaemon server start   # on the host, leave it running
```

Then set `ADB_HOST_SERVER=host.docker.internal:5037` in `.env` and restart the
container. `adb devices` inside the container now lists the host's devices.

**B. USB passthrough (Linux hosts only)**

```bash
make usb        # = docker compose -f docker-compose.yml -f docker-compose.usb.yml up -d
```

**C. Wi-Fi debugging**: enable *Wireless debugging* on the phone (Android 11+), pair it
from the host or the container with `adb pair <ip>:<port>`, then set `ADB_CONNECT=<ip>:5555` in `.env`.

### Emulator

There is no display in the container. The simplest option is to run the Android
emulator on the host and connect with option A. To run it **inside** the
container instead (Linux host with KVM):

```bash
INSTALL_EMULATOR=true docker compose build
```

```bash
make kvm
```

```bash
avdmanager create avd -n pixel -k "system-images;android-36;google_apis;x86_64" -d pixel_8
```

```bash
emulator -avd pixel -no-window -no-audio -no-boot-anim &
```

## Dev servers & ports

| Port | Use |
|---|---|
| 8081 | Metro bundler / Expo dev server |
| 19000–19002 | Older Expo tooling |
| 8080 | Flutter web: `flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080` |

For Expo Go on a phone, `npx expo start --tunnel` is the easiest option, because the phone can't
reach the container's internal IP.

## Example workflows

```bash
# Flutter
flutter create my_app && cd my_app
flutter test
flutter build apk --debug
```

```bash
# Expo (React Native)
npx create-expo-app@latest my-expo-app && cd my-expo-app
npx expo run:android          # needs a device (see above)
eas build -p ios --profile preview   # iOS build in the cloud
```

```bash
# Bare React Native
npx @react-native-community/cli@latest init MyApp && cd MyApp/android
./gradlew assembleDebug
```

## Checking the environment

```bash
devenv-doctor          # versions of every tool, SDK packages, devices, Claude auth
devenv-doctor --full   # also runs flutter doctor -v
```

`flutter doctor` reports Xcode, CocoaPods and Chrome as missing. That's expected on Linux.

## Customising

All versions are build args. Set them in `.env` and run `make build` again:

| Variable | Default |
|---|---|
| `FLUTTER_VERSION` | `3.47.9` (any Flutter stable release) |
| `NODE_MAJOR` | `24` |
| `ANDROID_PLATFORM` | `android-36` |
| `ANDROID_BUILD_TOOLS` | `36.0.0` |
| `ANDROID_NDK` | empty: Gradle downloads the NDK a project asks for |
| `INSTALL_EMULATOR` | `false` |
| `CLAUDE_CODE_VERSION` | `latest` |
| `USER_UID` / `USER_GID` | `1000` (match `id -u` / `id -g` so `/workspace` files stay yours) |

The Android SDK is writable by the `dev` user, so `sdkmanager "platforms;android-35"`
works at runtime too.

Named volumes keep Gradle, pub and npm caches plus the Claude login between runs.
`make clean` deletes them.

## VS Code

Open this folder in VS Code and use **Dev Containers: Reopen in Container**. The
included `.devcontainer/devcontainer.json` reuses the same compose service.

## Files

```
Dockerfile                  the image
docker-compose.yml          main service, ports, volumes
docker-compose.usb.yml      USB passthrough override (Linux)
docker-compose.kvm.yml      /dev/kvm override for the emulator (Linux)
.devcontainer/              VS Code Dev Containers config
config/CLAUDE.md            environment notes given to Claude Code
config/claude-settings.json default Claude Code permissions
scripts/entrypoint.sh       volume permissions, Claude defaults, adb wiring
scripts/devenv-doctor.sh    toolchain health check (installed as devenv-doctor)
Makefile                    shortcuts (make help)
```
