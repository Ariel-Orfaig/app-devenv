#!/usr/bin/env bash
# Quick health check of every toolchain in the image.
set -u

ok()   { printf '  \033[32m✔\033[0m %-14s %s\n' "$1" "$2"; }
fail() { printf '  \033[31m✘\033[0m %-14s %s\n' "$1" "$2"; FAILED=1; }
check() {
  local name=$1; shift
  local out
  if out=$("$@" 2>&1); then ok "$name" "${out%%$'\n'*}"; else fail "$name" "${out%%$'\n'*}"; fi
}

FAILED=0
echo "Toolchain:"
check java        java -version
check node        node --version
check npm         npm --version
check yarn        yarn --version
check pnpm        pnpm --version
check ruby        ruby --version
check bundler     bundle --version
check flutter     flutter --version
check dart        dart --version
check sdkmanager  sdkmanager --version
check adb         adb version
check eas         eas --version
check claude      claude --version

echo
echo "Installed Android SDK packages:"
sdkmanager --list_installed 2>/dev/null | awk 'NR>3 && NF {print "   " $1}'

echo
echo "Connected Android devices:"
adb devices 2>/dev/null | tail -n +2 | sed '/^$/d; s/^/   /' || true

if [ -e /dev/kvm ]; then ok kvm "available (emulator can run)"; else echo "  - kvm            not available (use a physical device or host emulator)"; fi
if [ -n "${ANTHROPIC_API_KEY:-}" ] || [ -f "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.credentials.json" ]; then
  ok claude-auth "configured"
else
  echo "  - claude-auth    not logged in yet: run 'claude' and follow /login, or set ANTHROPIC_API_KEY"
fi

if [ "${1:-}" = "--full" ]; then
  echo; flutter doctor -v
fi

exit $FAILED
