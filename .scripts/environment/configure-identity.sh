#!/usr/bin/env bash
# Reconfigure prompt identities without changing Android's real account.
set -Eeuo pipefail
CONFIG_DIR="$HOME/.config/mytermux"
mkdir -p "$CONFIG_DIR"
# Load existing generated profile values so reconfiguration does not reset choices.
if [[ -r "$CONFIG_DIR/profile.env" ]]; then
  # shellcheck source=/dev/null
  source "$CONFIG_DIR/profile.env"
fi
if [[ -r "$CONFIG_DIR/ubuntu-profile.env" ]]; then
  # shellcheck source=/dev/null
  source "$CONFIG_DIR/ubuntu-profile.env"
fi

valid_user() { [[ "$1" =~ ^[a-z_][a-z0-9_-]{0,31}$ && "$1" != root && "$1" != nobody ]]; }
valid_host() { [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9-]{0,62}$ ]]; }
ask() {
  local prompt="$1" value="$2" validator="$3" input
  while true; do
    read -r -p "$prompt [$value]: " input || true
    input="${input:-$value}"
    if "$validator" "$input"; then printf '%s' "$input"; return 0; fi
    printf 'Format tidak valid. Coba lagi.\n' >&2
  done
}

termux_user="$(ask 'Nama pengguna Termux (ditampilkan di prompt)' "${MYTERMUX_USER:-developer}" valid_user)"
termux_host="$(ask 'Host Termux' "${MYTERMUX_HOST:-android-dev}" valid_host)"
ubuntu_user="$(ask 'Username Linux untuk Ubuntu proot' "${UBUNTU_USER:-$termux_user}" valid_user)"
ubuntu_host="$(ask 'Host yang ditampilkan pada Ubuntu proot' "${UBUNTU_HOST:-ubuntu-dev}" valid_host)"
umask 077
printf "export MYTERMUX_USER='%s'\nexport MYTERMUX_HOST='%s'\n" "$termux_user" "$termux_host" > "$CONFIG_DIR/profile.env"
printf "export UBUNTU_DISTRO='ubuntu'\nexport UBUNTU_USER='%s'\nexport UBUNTU_HOST='%s'\n" "$ubuntu_user" "$ubuntu_host" > "$CONFIG_DIR/ubuntu-profile.env"
chmod 600 "$CONFIG_DIR/profile.env" "$CONFIG_DIR/ubuntu-profile.env"
printf '\nSaved Termux identity: %s@%s\n' "$termux_user" "$termux_host"
printf 'Saved Ubuntu identity: %s@%s\n' "$ubuntu_user" "$ubuntu_host"
printf 'Restart Zsh with: exec zsh\n'
if [[ -x "$HOME/.local/bin/ubuntu-install" ]]; then
  printf 'If Ubuntu is already installed, run ubuntu-install to apply/update its prompt identity.\n'
fi
