#!/usr/bin/env bash
# myTermux MacPro Dark installer — safe, modular, and repeatable.
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config/mytermux"
# Reuse existing generated identity values as defaults on later installer runs.
if [[ -r "$CONFIG_DIR/profile.env" ]]; then
  # shellcheck source=/dev/null
  source "$CONFIG_DIR/profile.env"
fi
if [[ -r "$CONFIG_DIR/ubuntu-profile.env" ]]; then
  # shellcheck source=/dev/null
  source "$CONFIG_DIR/ubuntu-profile.env"
fi
DEFAULT_TERMUX_USER="${MYTERMUX_USER:-developer}"
DEFAULT_TERMUX_HOST="${MYTERMUX_HOST:-android-dev}"
DEFAULT_UBUNTU_USER="${UBUNTU_USER:-$DEFAULT_TERMUX_USER}"
DEFAULT_UBUNTU_HOST="${UBUNTU_HOST:-ubuntu-dev}"
BACKUP_STAMP="$(date +%Y%m%d-%H%M%S)"
SKIP_PACKAGES=0
INSTALL_UBUNTU_NOW=ask
DO_UPGRADE=1

log() { printf '\033[1;34m[myTermux]\033[0m %s\n' "$*"; }
success() { printf '\033[1;32m[  OK  ]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[ WARN ]\033[0m %s\n' "$*" >&2; }
fail() { printf '\033[1;31m[ FAIL ]\033[0m %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF_HELP'
myTermux MacPro Dark installer

Usage: ./install.sh [options]

Options:
  --skip-packages  Configure dotfiles without installing Termux packages.
  --skip-ubuntu    Do not ask to install Ubuntu during this run.
  --ubuntu         Install Ubuntu proot and its full developer toolchain at the end.
  --no-upgrade     Run pkg update but do not run pkg upgrade.
  -h, --help       Show this help.

The first run asks for separate Termux display identity and Ubuntu Linux account/host.
Ubuntu installation may download several gigabytes. PRoot is userspace Linux, not
Android root and not a virtual machine.
EOF_HELP
}

while (($#)); do
  case "$1" in
    --skip-packages) SKIP_PACKAGES=1 ;;
    --skip-ubuntu) INSTALL_UBUNTU_NOW=no ;;
    --ubuntu) INSTALL_UBUNTU_NOW=yes ;;
    --no-upgrade) DO_UPGRADE=0 ;;
    -h|--help) usage; exit 0 ;;
    *) fail "Unknown option: $1 (use --help)" ;;
  esac
  shift
done

[[ -n "${PREFIX:-}" && -x "${PREFIX}/bin/pkg" ]] || fail "Run this installer inside Termux, not Ubuntu or a desktop Linux shell."

valid_user() { [[ "$1" =~ ^[a-z_][a-z0-9_-]{0,31}$ && "$1" != root && "$1" != nobody && "$1" != daemon ]]; }
valid_host() { [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9-]{0,62}$ ]]; }
ask_identity() {
  local label="$1" fallback="$2" validator="$3" value
  while true; do
    read -r -p "$label [$fallback]: " value || true
    value="${value:-$fallback}"
    if "$validator" "$value"; then printf '%s' "$value"; return 0; fi
    warn "Invalid value. Use letters, digits, underscore/hyphen; host labels cannot contain spaces or dots."
  done
}
ask_yes_no() {
  local prompt="$1" default="${2:-no}" answer
  if [[ "$default" == yes ]]; then prompt+=" [Y/n] "; else prompt+=" [y/N] "; fi
  read -r -p "$prompt" answer || true
  answer="${answer:-$([[ "$default" == yes ]] && printf y || printf n)}"
  [[ "$answer" =~ ^([yY]|[yY][eE][sS])$ ]]
}

read -r -p "Termux display username [${DEFAULT_TERMUX_USER}]: " TERMUX_USER || true
TERMUX_USER="${TERMUX_USER:-$DEFAULT_TERMUX_USER}"
while ! valid_user "$TERMUX_USER"; do
  warn "Username must start with a lowercase letter or underscore and use lowercase letters, digits, _ or -."
  TERMUX_USER="$(ask_identity 'Termux display username' "$DEFAULT_TERMUX_USER" valid_user)"
done
read -r -p "Termux host label [${DEFAULT_TERMUX_HOST}]: " TERMUX_HOST || true
TERMUX_HOST="${TERMUX_HOST:-$DEFAULT_TERMUX_HOST}"
while ! valid_host "$TERMUX_HOST"; do TERMUX_HOST="$(ask_identity 'Termux host label' "$DEFAULT_TERMUX_HOST" valid_host)"; done
read -r -p "Ubuntu Linux username [${DEFAULT_UBUNTU_USER}]: " UBUNTU_USER || true
UBUNTU_USER="${UBUNTU_USER:-$DEFAULT_UBUNTU_USER}"
while ! valid_user "$UBUNTU_USER"; do UBUNTU_USER="$(ask_identity 'Ubuntu Linux username' "$DEFAULT_UBUNTU_USER" valid_user)"; done
read -r -p "Ubuntu prompt host [${DEFAULT_UBUNTU_HOST}]: " UBUNTU_HOST || true
UBUNTU_HOST="${UBUNTU_HOST:-$DEFAULT_UBUNTU_HOST}"
while ! valid_host "$UBUNTU_HOST"; do UBUNTU_HOST="$(ask_identity 'Ubuntu prompt host' "$DEFAULT_UBUNTU_HOST" valid_host)"; done

if (( ! SKIP_PACKAGES )); then
  log "Refreshing Termux package indexes..."
  pkg update
  if (( DO_UPGRADE )) && ask_yes_no "Upgrade already-installed Termux packages before setup?" yes; then
    pkg upgrade -y
  fi

  read_package_manifest() {
    local manifest="$1" package
    local -a wanted=() available=()
    [[ -r "$manifest" ]] || { warn "Missing package manifest: $manifest"; return 0; }
    while IFS= read -r package || [[ -n "$package" ]]; do
      package="${package%%#*}"
      package="${package//[$'\t\r\n ']/}"
      [[ -z "$package" ]] && continue
      wanted+=("$package")
    done < "$manifest"
    for package in "${wanted[@]}"; do
      if apt-cache show "$package" >/dev/null 2>&1; then
        available+=("$package")
      else
        warn "Package not found in current Termux repositories; skipping: $package"
      fi
    done
    if ((${#available[@]})); then
      log "Installing ${#available[@]} packages from $(basename "$manifest")..."
      if ! pkg install -y "${available[@]}"; then
        warn "Grouped installation failed; retrying packages individually to identify any incompatible package."
        for package in "${available[@]}"; do
          pkg install -y "$package" || warn "Could not install package: $package"
        done
      fi
    fi
  }

  read_package_manifest "$ROOT_DIR/packages/termux.txt"
  if ask_yes_no "Install optional media and Termux:API utilities?" no; then
    read_package_manifest "$ROOT_DIR/packages/termux-optional.txt"
    warn "Termux:API commands also require the companion Termux:API Android app."
  fi
else
  warn "Skipping Termux package installation (--skip-packages). Missing tools may need manual installation."
fi

# Install Oh My Zsh and plugins without overwriting an existing functional install.
install_repo_if_missing() {
  local url="$1" target="$2"
  if [[ -d "$target/.git" ]]; then return 0; fi
  if [[ -e "$target" ]]; then
    local backup="${target}.backup.${BACKUP_STAMP}"
    warn "Moving incomplete existing directory to $backup"
    mv "$target" "$backup"
  fi
  log "Cloning $(basename "$target")..."
  git clone --depth=1 "$url" "$target" || warn "Could not clone $url; the fallback prompt still works."
}
if command -v git >/dev/null 2>&1; then
  install_repo_if_missing https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh"
  mkdir -p "$HOME/.oh-my-zsh/custom/plugins"
  install_repo_if_missing https://github.com/zsh-users/zsh-autosuggestions.git "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions"
  install_repo_if_missing https://github.com/zsh-users/zsh-syntax-highlighting.git "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting"
  install_repo_if_missing https://github.com/joshskidmore/zsh-fzf-history-search.git "$HOME/.oh-my-zsh/custom/plugins/zsh-fzf-history-search"
  install_repo_if_missing https://github.com/marlonrichert/zsh-autocomplete.git "$HOME/.oh-my-zsh/custom/plugins/zsh-autocomplete"
else
  warn "Git is unavailable, so Oh My Zsh and plugins were not downloaded."
fi

# Overlay individual files, preserving unrelated configuration and timestamped backups.
sync_file() {
  local source_file="$1" target_file="$2" backup
  mkdir -p "$(dirname "$target_file")"
  if [[ -e "$target_file" || -L "$target_file" ]]; then
    if [[ -f "$source_file" && -f "$target_file" ]] && cmp -s "$source_file" "$target_file"; then
      return 0
    fi
    backup="${target_file}.backup.${BACKUP_STAMP}"
    cp -a "$target_file" "$backup"
  fi
  rm -rf "$target_file"
  cp -a "$source_file" "$target_file"
}

sync_tree() {
  local source_dir="$1" target_dir="$2" source_file relative target_file
  [[ -d "$source_dir" ]] || return 0
  mkdir -p "$target_dir"
  while IFS= read -r -d '' source_file; do
    relative="${source_file#"$source_dir"/}"
    target_file="$target_dir/$relative"
    sync_file "$source_file" "$target_file"
  done < <(find "$source_dir" \( -type f -o -type l \) -print0)
}

log "Deploying MacPro Dark dotfiles and developer helpers..."
for entry in .aliases .autostart .bashrc .colorscheme .config .fonts .gitconfig .inputrc .lang-icons .local .oh-my-zsh .p10k.zsh .scripts .termux .tmux.conf .zshrc; do
  source_path="$ROOT_DIR/$entry"
  [[ -e "$source_path" || -L "$source_path" ]] || continue
  if [[ -d "$source_path" ]]; then
    sync_tree "$source_path" "$HOME/$entry"
  else
    sync_file "$source_path" "$HOME/$entry"
  fi
done
sync_tree "$ROOT_DIR/packages" "$CONFIG_DIR/packages"

umask 077
mkdir -p "$CONFIG_DIR"
printf "export MYTERMUX_USER='%s'\nexport MYTERMUX_HOST='%s'\n" "$TERMUX_USER" "$TERMUX_HOST" > "$CONFIG_DIR/profile.env"
printf "export UBUNTU_DISTRO='ubuntu'\nexport UBUNTU_USER='%s'\nexport UBUNTU_HOST='%s'\n" "$UBUNTU_USER" "$UBUNTU_HOST" > "$CONFIG_DIR/ubuntu-profile.env"
chmod 600 "$CONFIG_DIR/profile.env" "$CONFIG_DIR/ubuntu-profile.env"

if command -v chsh >/dev/null 2>&1 && command -v zsh >/dev/null 2>&1; then
  chsh -s zsh >/dev/null 2>&1 || warn "Could not change the default shell automatically. Run 'chsh -s zsh' manually if desired."
fi
if command -v termux-reload-settings >/dev/null 2>&1; then
  termux-reload-settings >/dev/null 2>&1 || warn "Could not reload Termux settings automatically; reopen the session to apply colors/font."
fi

success "Termux profile configured as ${TERMUX_USER}@${TERMUX_HOST}."
success "Ubuntu profile configured as ${UBUNTU_USER}@${UBUNTU_HOST}."
success "Backups of replaced files use the suffix .backup.${BACKUP_STAMP}."

if [[ "$INSTALL_UBUNTU_NOW" == ask ]]; then
  if ask_yes_no "Install Ubuntu proot with full Linux/Android/kernel build dependencies now? This may need several GB." no; then
    INSTALL_UBUNTU_NOW=yes
  else
    INSTALL_UBUNTU_NOW=no
  fi
fi
if [[ "$INSTALL_UBUNTU_NOW" == yes ]]; then
  "$HOME/.local/bin/ubuntu-install"
fi

cat <<EOF_DONE

Setup complete.

Termux prompt : ${TERMUX_USER}@${TERMUX_HOST}
Ubuntu prompt: ${UBUNTU_USER}@${UBUNTU_HOST}

Useful commands:
  mytermux-doctor  Check installed tools, profiles, disk space, and Ubuntu status.
  mytermux-setup   Reconfigure the Termux and Ubuntu display identities.
  ubuntu-install   Install/update Ubuntu proot and its development dependencies.
  ubuntu           Enter Ubuntu as ${UBUNTU_USER} (normal user).
  ubroot           Enter Ubuntu's simulated-root administration shell.
  ubuntu-update    Update Ubuntu packages from Termux.
  exec zsh         Reload the configured prompt now.

Important: the Termux name is prompt metadata, not an Android account change.
PRoot provides a Linux userspace but does not grant real Android root privileges.
EOF_DONE
