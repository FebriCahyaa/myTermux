# Optional Bash fallback, sharing the same MacPro Dark identity.
[[ -r "$HOME/.config/mytermux/profile.env" ]] && source "$HOME/.config/mytermux/profile.env"
export MYTERMUX_ENV="termux"
export MYTERMUX_USER="${MYTERMUX_USER:-developer}"
export MYTERMUX_HOST="${MYTERMUX_HOST:-android-dev}"
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:${PREFIX:+$PREFIX/bin:}$PATH"

if [[ $- == *i* ]]; then
  if command -v starship >/dev/null 2>&1; then
    export STARSHIP_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/starship.toml"
    eval "$(starship init bash)"
  else
    PS1="\[\e[1;32m\]${MYTERMUX_USER}\[\e[0m\]@\[\e[1;34m\]${MYTERMUX_HOST}\[\e[0m\] \[\e[1;35m\]\w\[\e[0m\]\n\[\e[1;32m\]❯\[\e[0m\] "
  fi
fi
