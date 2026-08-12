#!/bin/bash

set -euo pipefail

REPO_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT

export HOME="$TEST_ROOT/home"
export PATH="$TEST_ROOT/bin:$PATH"
mkdir -p "$HOME/.config/hypr" "$HOME/.config/omarchy/plugins" "$TEST_ROOT/bin" "$TEST_ROOT/omarchy/shell/services"
cp -R -- "$REPO_DIR" "$HOME/.config/omarchy/plugins/next-key"
printf '%s\n' '-- user bindings' 'o.bind("SUPER + Z", "Example", "example")' >"$HOME/.config/hypr/bindings.lua"
: >"$TEST_ROOT/omarchy/shell/services/PluginRegistry.qml"
export OMARCHY_PATH="$TEST_ROOT/omarchy"

for command in omarchy-shell qs; do
  printf '#!/bin/sh\nexit 0\n' >"$TEST_ROOT/bin/$command"
  chmod +x "$TEST_ROOT/bin/$command"
done

cat >"$TEST_ROOT/bin/omarchy-plugin-validate" <<'SH'
#!/bin/sh
test -f "$1/manifest.json"
SH
chmod +x "$TEST_ROOT/bin/omarchy-plugin-validate"

cat >"$TEST_ROOT/bin/hyprctl" <<'SH'
#!/bin/sh
case "$1" in
  repl)
    case "$2" in
      *'type(hl.on)'*) printf 'function\tfunction\tfunction\tfunction\n' ;;
      *) printf 'ok\n' ;;
    esac
    ;;
  reload|configerrors) exit 0 ;;
  *) exit 1 ;;
esac
SH
chmod +x "$TEST_ROOT/bin/hyprctl"

"$HOME/.config/omarchy/plugins/next-key/bin/install-hook" >/dev/null
"$HOME/.config/omarchy/plugins/next-key/bin/install-hook" >/dev/null
test "$(grep -Fc -- '-- next-key:start' "$HOME/.config/hypr/bindings.lua")" -eq 1
luac -p "$HOME/.config/hypr/bindings.lua"

"$HOME/.config/omarchy/plugins/next-key/bin/uninstall-hook" >/dev/null
"$HOME/.config/omarchy/plugins/next-key/bin/uninstall-hook" >/dev/null
! grep -Fq -- '-- next-key:start' "$HOME/.config/hypr/bindings.lua"
grep -Fq -- 'o.bind("SUPER + Z"' "$HOME/.config/hypr/bindings.lua"
luac -p "$HOME/.config/hypr/bindings.lua"

echo "hooks: ok"
