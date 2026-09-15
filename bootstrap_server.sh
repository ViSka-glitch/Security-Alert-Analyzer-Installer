#!/usr/bin/env bash
set -Eeuo pipefail
set +x
umask 077

INSTALLER_URL="${SAA_INSTALLER_URL:-}"
INSTALLER_SHA256="${SAA_INSTALLER_SHA256:-}"
SIGNATURE_URL="${SAA_INSTALLER_SIGNATURE_URL:-}"
PUBLIC_KEY="${SAA_INSTALLER_PUBLIC_KEY:-/etc/saa/installer-public.pem}"
AUTH_HEADER_FILE="${SAA_INSTALLER_AUTH_HEADER_FILE:-}"

fail() { echo "Fehler: $*" >&2; exit 1; }

# Trust material must not be replaceable through a writable ancestor directory.
protected_file() {
  local path="$1" secret="$2" mode
  [[ "$path" == /* && -f "$path" && ! -L "$path" ]] || fail "Geschützte Datei fehlt oder ist ein Symlink."
  [[ "$(realpath -e -- "$path")" == "$path" ]] || fail "Nur kanonische Dateipfade sind erlaubt."
  mode="$(stat -c '%a' -- "$path")"
  if [[ "$secret" == yes ]]; then
    (( (8#$mode & 077) == 0 )) || fail "Zugangsdatei darf nur für root zugänglich sein."
  fi
  while :; do
    [[ "$(stat -c '%u' -- "$path")" == 0 ]] || fail "Vertrauensdatei und Verzeichnisse müssen root gehören."
    mode="$(stat -c '%a' -- "$path")"
    (( (8#$mode & 022) == 0 )) || fail "Vertrauenspfad ist für andere Benutzer beschreibbar."
    [[ "$path" != / ]] || break
    path="$(dirname -- "$path")"
  done
}

[[ $EUID -eq 0 ]] || { echo "Fehler: Der Bootstrapper muss über sudo ausgeführt werden." >&2; exit 1; }
[[ "$INSTALLER_URL" == https://* ]] || {
  echo "Fehler: SAA_INSTALLER_URL muss eine freigegebene HTTPS-Adresse sein." >&2
  exit 1
}
[[ "$INSTALLER_SHA256" =~ ^[0-9a-fA-F]{64}$ ]] || {
  echo "Fehler: SAA_INSTALLER_SHA256 muss eine vollständige SHA-256-Prüfsumme sein." >&2
  exit 1
}
[[ "$SIGNATURE_URL" == https://* ]] || fail "SAA_INSTALLER_SIGNATURE_URL muss eine HTTPS-Adresse sein."
# A downloaded bootstrap needs bash/root and a transport already. Install only
# missing verification utilities, using the operator's configured package trust.
if ! command -v openssl >/dev/null || ! command -v sha256sum >/dev/null || ! command -v curl >/dev/null; then
  confirmed=false
  non_interactive=false
  for argument in "$@"; do
    [[ "$argument" != --dry-run ]] || fail "Prüfwerkzeuge fehlen; Dry-Run installiert keine Pakete."
    [[ "$argument" != --confirm-host-changes ]] || confirmed=true
    [[ "$argument" != --non-interactive ]] || non_interactive=true
  done
  echo "Fehlende Prüfwerkzeuge installieren: ca-certificates, curl, openssl, coreutils."
  if ! $confirmed; then
    $non_interactive && fail "Paketinstallation benötigt --confirm-host-changes."
    read -r -p "Installation aus den freigegebenen Paketquellen erlauben? [ja/NEIN]: " answer </dev/tty || fail "Interaktives Terminal fehlt."
    [[ "$answer" == ja ]] || fail "Paketinstallation abgebrochen."
  fi
  . /etc/os-release
  case "$ID:$VERSION_ID" in
    ubuntu:24.04) apt-get update; apt-get install --no-remove --no-upgrade -y ca-certificates curl openssl coreutils ;;
    rhel:9*|rhel:10*) dnf install -y ca-certificates curl openssl coreutils ;;
    *) fail "Prüfwerkzeuge auf diesem Betriebssystem manuell installieren." ;;
  esac
fi
protected_file "$PUBLIC_KEY" no
if [[ -n "$AUTH_HEADER_FILE" ]]; then
  protected_file "$AUTH_HEADER_FILE" yes
  # Never forward a private GitHub credential to a freely configurable host.
  for url in "$INSTALLER_URL" "$SIGNATURE_URL"; do
    [[ "$url" =~ ^https://api\.github\.com/repos/ViSka-glitch/Security-Alert-Analyzer/releases/assets/[0-9]+$ ]] || fail "Authentifizierter Abruf ist nur für private SAA-Release-Assets erlaubt."
  done
  [[ "$(wc -l < "$AUTH_HEADER_FILE")" == 1 ]] || fail "Zugangsdatei muss genau eine Headerzeile enthalten."
  LC_ALL=C grep -Eq '^Authorization: Bearer [A-Za-z0-9_]+$' "$AUTH_HEADER_FILE" || fail "Ungültiges Zugangsdateiformat."
fi

TEMPORARY_DIRECTORY="$(mktemp -d -t saa-bootstrap.XXXXXXXX)"
cleanup() {
  rm -rf -- "$TEMPORARY_DIRECTORY"
}
trap cleanup EXIT
INSTALLER="$TEMPORARY_DIRECTORY/install_server.sh"

download() {
  local headers=()
  if [[ -n "$AUTH_HEADER_FILE" ]]; then
    headers=(--header "@$AUTH_HEADER_FILE" --header 'Accept: application/octet-stream')
  fi
  # curl strips Authorization on cross-host redirects; never use location-trusted.
  curl --disable --fail --silent --show-error --location \
    --proto '=https' --proto-redir '=https' --tlsv1.2 \
    --connect-timeout 15 --max-time 120 --max-filesize 1048576 \
    "${headers[@]}" --output "$2" "$1"
}
download "$INSTALLER_URL" "$INSTALLER" || fail "Installer konnte nicht geladen werden."
download "$SIGNATURE_URL" "$TEMPORARY_DIRECTORY/installer.sig" || fail "Signatur konnte nicht geladen werden."
printf '%s  %s\n' "$INSTALLER_SHA256" "$INSTALLER" | sha256sum --check --status || fail "Installer-Prüfsumme stimmt nicht überein."
openssl dgst -sha256 -verify "$PUBLIC_KEY" -signature "$TEMPORARY_DIRECTORY/installer.sig" "$INSTALLER" >/dev/null 2>&1 || fail "Installer-Signatur ist ungültig."
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
