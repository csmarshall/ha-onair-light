#!/usr/bin/env bash
#
# deploy.sh — install the Status Light files into a Home Assistant config.
#
# Copies status_light.yaml into the HA packages dir and streamdeck-theme.yml
# into the HA www dir, each with a timestamped backup of any existing file.
# Reloading/restarting HA to apply is left to you.
#
# Paths are overridable by environment variable. HA Container users commonly
# map the container's /config to a host path — point these at wherever your
# HA config lives:
#
#   HA_PACKAGES=/path/to/config/packages HA_WWW=/path/to/config/www ./deploy.sh
#
# The packages dir is often root-owned, so you may need to run this with sudo
# (e.g. `sudo ./deploy.sh`). It is intentionally NOT hard-coded to use sudo —
# run it however your setup requires.
#
# Usage: ./deploy.sh
#
set -euo pipefail
unset TMOUT

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# HA config locations — override via env var. HA Container installs typically
# map /config to a host directory; adjust to match yours.
HA_PACKAGES="${HA_PACKAGES:-/config/packages}"
HA_WWW="${HA_WWW:-/config/www}"

PKG_SRC="${HERE}/status_light.yaml"
PKG_DEST="${HA_PACKAGES}/status_light.yaml"
THEME_SRC="${HERE}/streamdeck-theme.yml"
THEME_DEST="${HA_WWW}/streamdeck-theme.yml"
STAMP="$(date +'%F-%H%M.%S')"

log() { printf '%s [%s] %s\n' "$(date +'%F %T')" "$1" "$2"; }

# Copy a file into place, backing up any existing destination first.
install_file() {
  local src="$1" dest="$2" dest_dir
  dest_dir="$(dirname "$dest")"

  [[ -f "$src" ]]      || { log ERROR "source not found: $src"; exit 1; }
  [[ -d "$dest_dir" ]] || { log ERROR "dest dir not found: $dest_dir"; exit 1; }

  if [[ -f "$dest" ]]; then
    log INFO "backing up existing ${dest} -> ${dest}.bak.${STAMP}"
    cp -p "$dest" "${dest}.bak.${STAMP}"
  fi

  log INFO "copying ${src} -> ${dest}"
  cp "$src" "$dest"
  chmod 644 "$dest"
}

install_file "$PKG_SRC" "$PKG_DEST"
install_file "$THEME_SRC" "$THEME_DEST"

log INFO "done. Reload or restart Home Assistant to apply."
