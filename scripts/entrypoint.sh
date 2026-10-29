#!/usr/bin/env bash
# Container entrypoint: prepares mounted volumes and Claude Code defaults,
# then runs the given command (an interactive shell by default).
set -e

# Named volumes / bind mounts may come up owned by root: hand them to the dev user.
for d in "$HOME/.claude" "$HOME/.gradle" "$HOME/.pub-cache" "$HOME/.npm" \
         "$HOME/.npm-global" "$HOME/.android" /workspace; do
  if [ -d "$d" ] && [ ! -w "$d" ]; then
    sudo chown "$(id -u):$(id -g)" "$d" 2>/dev/null || true
  fi
done

# Seed Claude Code with environment notes and default settings (only once,
# so your own edits in the persisted ~/.claude volume are kept).
mkdir -p "$CLAUDE_CONFIG_DIR"
[ -f "$CLAUDE_CONFIG_DIR/CLAUDE.md" ] || cp /opt/devenv/CLAUDE.md "$CLAUDE_CONFIG_DIR/CLAUDE.md"
[ -f "$CLAUDE_CONFIG_DIR/settings.json" ] || cp /opt/devenv/claude-settings.json "$CLAUDE_CONFIG_DIR/settings.json"

# Git identity from env, if provided.
[ -n "$GIT_USER_NAME" ]  && git config --global user.name  "$GIT_USER_NAME"
[ -n "$GIT_USER_EMAIL" ] && git config --global user.email "$GIT_USER_EMAIL"

# Use the adb server running on the host (keeps USB devices on the host side).
[ -n "$ADB_HOST_SERVER" ] && export ADB_SERVER_SOCKET="tcp:$ADB_HOST_SERVER"

# Optional: connect to an emulator/device exposed over TCP (e.g. "host.docker.internal:5555").
if [ -n "$ADB_CONNECT" ] && [ -z "$ADB_SERVER_SOCKET" ]; then
  adb connect "$ADB_CONNECT" >/dev/null 2>&1 || echo "warn: adb connect $ADB_CONNECT failed"
fi

if [ -t 1 ] && [ "$#" -gt 0 ] && [ "$1" = "bash" ]; then
  cat <<MSG

  📱 Mobile dev environment
     Flutter $(flutter --version 2>/dev/null | head -1 | awk '{print $2}') · Node $(node -v) · Java $(java -version 2>&1 | head -1 | awk -F'"' '{print $2}') · Android SDK at \$ANDROID_HOME
     Run 'claude' to start Claude Code, 'devenv-doctor' to check the toolchain.

MSG
fi

exec "$@"
