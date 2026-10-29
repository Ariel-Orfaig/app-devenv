# Environment: mobile dev container

You are running inside a Linux (Ubuntu 24.04) Docker container built for
cross-platform mobile development. The user's projects are mounted at
`/workspace`.

## Installed toolchain
- **Java**: OpenJDK 17 (`$JAVA_HOME=/opt/java`)
- **Android SDK**: `$ANDROID_HOME=/opt/android-sdk` — cmdline-tools, platform-tools
  (`adb`), platform + build-tools, cmake. The SDK is writable: install extra
  packages with `sdkmanager "<package>"`; Gradle also auto-downloads a missing NDK.
- **Flutter / Dart**: `/opt/flutter` (stable). Use `flutter create`, `flutter test`,
  `flutter build apk|appbundle|web`.
- **Node.js LTS** with npm, and yarn/pnpm via corepack. React Native / Expo via
  `npx` (`npx create-expo-app`, `npx @react-native-community/cli init`). `eas` CLI
  is installed for Expo cloud builds.
- **Ruby + Bundler** for fastlane (install per project with `bundle install`).

## Limits to keep in mind
- **No Xcode / macOS**: iOS apps cannot be compiled, signed or run in a simulator
  here. You *can* write and edit Swift/Objective-C/iOS config, Dart and JS/TS code,
  run unit tests that don't need iOS, and trigger remote iOS builds
  (`eas build -p ios`, CI on macOS runners, Codemagic). Never claim an iOS build
  succeeded locally.
- **No GUI**: there is no display. The Android emulator only works if the image
  was built with `INSTALL_EMULATOR=true` and `/dev/kvm` is passed in; run it
  headless (`emulator -avd <name> -no-window -no-audio`). Usually a physical
  device or an emulator on the host is reached through `adb` (check `adb devices`).
- Metro (8081), Expo (19000-19002) and Flutter web (8080) ports are published to
  the host; bind dev servers to `0.0.0.0` (e.g. `flutter run -d web-server
  --web-hostname 0.0.0.0 --web-port 8080`).
- Never read or print signing keys (`*.jks`, `*.keystore`, `key.properties`) or `.env` secrets.

## Handy commands
- `devenv-doctor` — check every tool; `devenv-doctor --full` adds `flutter doctor -v`
- Android release build (RN): `cd android && ./gradlew assembleRelease`
- Flutter: `flutter pub get && flutter analyze && flutter test`
