#!/usr/bin/env bash
set -Eeuo pipefail

INSTALLER_URL="${SAA_INSTALLER_URL:-}"
INSTALLER_SHA256="${SAA_INSTALLER_SHA256:-}"

[[ $EUID -eq 0 ]] || { echo "Fehler: Der Bootstrapper muss über sudo ausgeführt werden." >&2; exit 1; }
[[ "$INSTALLER_URL" == https://* ]] || {
  echo "Fehler: SAA_INSTALLER_URL muss eine freigegebene HTTPS-Adresse sein." >&2
  exit 1
}
[[ "$INSTALLER_SHA256" =~ ^[0-9a-fA-F]{64}$ ]] || {
  echo "Fehler: SAA_INSTALLER_SHA256 muss eine vollständige SHA-256-Prüfsumme sein." >&2
  exit 1
}
command -v curl >/dev/null || { echo "Fehler: curl fehlt." >&2; exit 1; }
command -v sha256sum >/dev/null || { echo "Fehler: sha256sum fehlt." >&2; exit 1; }

TEMPORARY_DIRECTORY="$(mktemp -d -t saa-bootstrap.XXXXXXXX)"
cleanup() {
  rm -rf -- "$TEMPORARY_DIRECTORY"
}
trap cleanup EXIT
INSTALLER="$TEMPORARY_DIRECTORY/install_server.sh"

curl --fail --silent --show-error --location \
  --proto '=https' --tlsv1.2 \
  --output "$INSTALLER" "$INSTALLER_URL"
printf '%s  %s\n' "$INSTALLER_SHA256" "$INSTALLER" | sha256sum --check --status
chmod 0700 "$INSTALLER"

echo "Installer geprüft. Die geführte Installation wird gestartet."
NON_INTERACTIVE=false
for argument in "$@"; do
  [[ "$argument" != --non-interactive && "$argument" != --dry-run ]] || NON_INTERACTIVE=true
done
if $NON_INTERACTIVE; then
  bash "$INSTALLER" install "$@"
elif ( : </dev/tty ) 2>/dev/null; then
  # In a curl | bash invocation stdin contains the script, not user input.
  bash "$INSTALLER" install "$@" </dev/tty
else
  echo "Fehler: Die geführte Installation benötigt ein Terminal. Interaktive SSH-Sitzung öffnen oder --non-interactive verwenden." >&2
  exit 1
fi
