#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

printf '[check] Bash syntax...\n'
bash -n install.sh \
  .local/bin/ubuntu .local/bin/ubroot .local/bin/ubuntu-install \
  .local/bin/ubuntu-update .local/bin/mytermux-doctor \
  .scripts/ubuntu/install.sh .scripts/ubuntu/bootstrap-inside.sh \
  .scripts/environment/configure-identity.sh .autostart .bashrc .zshrc .aliases

if command -v zsh >/dev/null 2>&1; then
  printf '[check] Zsh syntax...\n'
  zsh -n .zshrc .aliases
else
  printf '[skip] Zsh is not installed on this validation host.\n'
fi

if command -v python3 >/dev/null 2>&1; then
  printf '[check] Starship TOML syntax...\n'
  python3 - <<'PY'
import sys
try:
    import tomllib
except ImportError:
    print('tomllib unavailable; skipping TOML validation')
    sys.exit(0)
with open('.config/starship.toml', 'rb') as stream:
    config = tomllib.load(stream)
assert 'format' in config
assert 'MYTERMUX_USER' in config.get('env_var', {})
assert 'MYTERMUX_HOST' in config.get('env_var', {})
print('Starship TOML parsed successfully')
PY
fi

printf '[check] Generated Ubuntu prompt files...\n'
TMP_VALIDATION="$(mktemp -d)"
trap 'rm -rf "$TMP_VALIDATION"' EXIT
awk '/^write_starship_config\(\) \{/ { in_functions=1 } /^configure_home \/root root/ { in_functions=0 } in_functions { print }' .scripts/ubuntu/bootstrap-inside.sh > "$TMP_VALIDATION/bootstrap-functions.sh"
HOME="$TMP_VALIDATION" UBUNTU_HOST="validation-host" bash -c \
  'set -euo pipefail; source "$1"; configure_home "$2/home/developer" developer' \
  _ "$TMP_VALIDATION/bootstrap-functions.sh" "$TMP_VALIDATION"
bash -n \
  "$TMP_VALIDATION/home/developer/.config/mytermux/prompt.zsh" \
  "$TMP_VALIDATION/home/developer/.config/mytermux/prompt.bash" \
  "$TMP_VALIDATION/home/developer/.zshrc" \
  "$TMP_VALIDATION/home/developer/.bashrc"
grep -Fq '[[ $# -eq 1 ]]' "$TMP_VALIDATION/home/developer/.config/mytermux/prompt.zsh"
grep -Fq 'validation-host' "$TMP_VALIDATION/home/developer/.config/mytermux/prompt.zsh"
if command -v python3 >/dev/null 2>&1; then
  python3 - "$TMP_VALIDATION/home/developer/.config/starship.toml" <<'PYTOML'
import sys
from pathlib import Path
try:
    import tomllib
except ImportError:
    raise SystemExit(0)
config = tomllib.loads(Path(sys.argv[1]).read_text())
assert "MYTERMUX_USER" in config.get("env_var", {})
assert "MYTERMUX_HOST" in config.get("env_var", {})
PYTOML
fi
rm -rf "$TMP_VALIDATION"
trap - EXIT

printf '[check] Required files...\n'
for path in \
  .config/starship.toml .termux/colors.properties .termux/termux.properties \
  packages/termux.txt packages/termux-optional.txt packages/ubuntu-common.txt \
  .scripts/ubuntu/install.sh .scripts/ubuntu/bootstrap-inside.sh \
  .local/bin/ubuntu .local/bin/ubroot .local/bin/ubuntu-install \
  .local/bin/ubuntu-update .local/bin/mytermux-doctor; do
  [[ -s "$path" ]] || { echo "Missing or empty: $path" >&2; exit 1; }
done

printf '[check] Shell scripts are valid.\n'
