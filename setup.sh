#!/usr/bin/env bash
#
# setup.sh — generate a unique webhook id for the Status Light package.
#
# Replaces the `statuslight_meeting_CHANGE_ME` placeholder in status_light.yaml
# with a freshly generated random id, saving a .bak of the original. Run this
# once after copying the package into your HA config.
#
# Usage: ./setup.sh
#
set -euo pipefail
unset TMOUT

usage() {
  cat <<'EOF'
Usage: ./setup.sh

Generates a random webhook id (statuslight_meeting_<16 hex chars>) and writes
it into status_light.yaml in place, replacing the CHANGE_ME placeholder. A
backup is saved as status_light.yaml.bak.

After running:
  1. Reload the YAML/automations or restart Home Assistant so the new
     webhook id takes effect.
  2. Create a Nabu Casa cloud webhook for this automation:
       - In the HA UI, open the "Status Light - MuteDeck Receiver" automation,
         or Settings -> Home Assistant Cloud -> Webhooks, and toggle it on to
         mint a public https://hooks.nabu.casa/... URL.
       - (Advanced/alternative: call the cloud/cloudhook/create websocket API.)
  3. Paste that hooks.nabu.casa/... URL into MuteDeck -> Settings ->
     Notifications on EACH machine you want to report meeting state.
EOF
}

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
esac

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG="${HERE}/status_light.yaml"
PLACEHOLDER="statuslight_meeting_CHANGE_ME"

log() { printf '%s [%s] %s\n' "$(date +'%F %T')" "$1" "$2"; }

[[ -f "$PKG" ]] || { log ERROR "status_light.yaml not found next to setup.sh: $PKG"; exit 1; }

# Idempotency: if the placeholder is gone, assume it's already configured.
if ! grep -q "$PLACEHOLDER" "$PKG"; then
  log INFO "no '${PLACEHOLDER}' placeholder found — status_light.yaml looks already configured. Nothing to do."
  exit 0
fi

# Generate 16 hex chars (8 random bytes) with whatever tool is available.
if command -v openssl >/dev/null 2>&1; then
  HEX="$(openssl rand -hex 8)"
elif command -v xxd >/dev/null 2>&1; then
  HEX="$(head -c8 /dev/urandom | xxd -p)"
else
  log ERROR "need either 'openssl' or 'xxd' to generate a random id"
  exit 1
fi

NEW_ID="statuslight_meeting_${HEX}"

cp -p "$PKG" "${PKG}.bak"
log INFO "backed up ${PKG} -> ${PKG}.bak"

# Portable in-place replace (no GNU-sed -i dependency).
tmp="$(mktemp)"
sed "s/${PLACEHOLDER}/${NEW_ID}/g" "$PKG" > "$tmp"
mv "$tmp" "$PKG"

log INFO "webhook id set to: ${NEW_ID}"
echo
echo "Next steps:"
echo "  1. Reload the YAML/automations or restart Home Assistant."
echo "  2. Create a Nabu Casa cloud webhook for the 'Status Light - MuteDeck"
echo "     Receiver' automation (HA UI: Settings -> Home Assistant Cloud ->"
echo "     Webhooks, toggle it on) to mint a https://hooks.nabu.casa/... URL."
echo "  3. Paste that URL into MuteDeck -> Settings -> Notifications on each"
echo "     machine."
