#!/usr/bin/env bash
set -Eeuo pipefail
set +x
umask 077
VERIFY_ONLY=false
for argument in "$@"; do
  [[ "$argument" != --verify-only ]] || VERIFY_ONLY=true
done

INSTALLER_URL="${SAA_INSTALLER_URL-https://api.github.com/repos/ViSka-glitch/Security-Alert-Analyzer/releases/assets/564934788}"
INSTALLER_SHA256="${SAA_INSTALLER_SHA256-6d3b9525c9b3db27cc72a5bdde5270e6fd5609d1021bc837ec87277516839109}"
SIGNATURE_URL="${SAA_INSTALLER_SIGNATURE_URL-https://api.github.com/repos/ViSka-glitch/Security-Alert-Analyzer/releases/assets/564934786}"
PUBLIC_KEY="${SAA_INSTALLER_PUBLIC_KEY:-}"
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
  $VERIFY_ONLY && fail "Prüfwerkzeuge fehlen; --verify-only installiert keine Pakete."
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
TEMPORARY_DIRECTORY="$(mktemp -d /run/saa-bootstrap.XXXXXXXX)"
cleanup() {
  rm -rf -- "$TEMPORARY_DIRECTORY"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
INSTALLER="$TEMPORARY_DIRECTORY/install_server.sh"

if [[ -z "$PUBLIC_KEY" ]]; then
  PUBLIC_KEY="$TEMPORARY_DIRECTORY/public.pem"
  # Public verification key only. Trust derives from the reviewed bootstrap version.
  printf '%s\n' '-----BEGIN PUBLIC KEY-----
MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA04q0kAg03SE6v612cQLR
Hyzlj0qbCOetaFsUUKX93QeThEcJe06UYKOSwH1gW7hOUhuh/d2lQvjQK5QVRAy1
2GCKvdG1ex6mEGs6z1isi70smcos62BdVjp8NzYUA74Ja0iaLZa/q24wQWpJXS7h
tF94loY0tpnTed5Nlny8iRQlX2W2aGNLip+bvsyVTY44A4+QeqcA4NO6JDjKFC2p
ial+qXg1jx0OpJNkrGE9SVyII8Zg3LiJx/LfOp9gebcd7E6xoRSk6rAwags0TPRo
naK8OJixSX0YgcAZVJHINlP/S14vAi9qzCQ5AFeNkRyt445Y4rm/sfYnpKinmtDo
gRzQD6FMVBlabCcX8XuA73v1ReXrIXr1GXWx83XWL+NnxOsGk5JJ/02fsvzoGjR4
fsmCJbd+50aZpHf/GfIOU0gPQ7KMqe8dGdltbWEBZQOBCWmjb3aJhvYgm0xU2uxd
ZMEAt9BLgYRRxW+QTo4KZtdg77g6WlK4FiNVjGROF9R3jVoLQCAab+9tjTsEes4o
FrXko5m2qz1WohE1+eWYJO4y6/H2hltn7wGqYSUqxX7KzroxNTkVZW2cV4/REFNe
53BjdeNYzDC5Y73JPwY09AiFi/wcU3/Xivxmn7rWulYgqWBeaYiKwoSsNemPjEGZ
QFXYOd01dc6g8d+LjvT5BPkCAwEAAQ==
-----END PUBLIC KEY-----' > "$PUBLIC_KEY"
fi
protected_file "$PUBLIC_KEY" no
if [[ -z "$AUTH_HEADER_FILE" && "$INSTALLER_URL" == https://api.github.com/* ]]; then
  for argument in "$@"; do
    [[ "$argument" != --non-interactive ]] || fail "Nichtinteraktiv ist eine geschützte Zugangsdatei erforderlich."
  done
  echo "Privater SAA-Testrelease: GitHub-Zugang wird nur für diesen Abruf verwendet."
  echo "Dies ist eine verdeckte Tokenabfrage, keine GitHub-Browseranmeldung."
  read -r -s -p "GitHub-Zugriffstoken (nicht in Befehle oder Chats kopieren): " access_token </dev/tty || fail "Kein Terminal verfügbar; geschützte Zugangsdatei verwenden."
  echo
  [[ "$access_token" =~ ^[A-Za-z0-9_]+$ ]] || fail "Ungültiges Tokenformat."
  AUTH_HEADER_FILE="$TEMPORARY_DIRECTORY/auth-header"
  printf 'Authorization: Bearer %s\n' "$access_token" > "$AUTH_HEADER_FILE"
  unset access_token
fi
if [[ -n "$AUTH_HEADER_FILE" ]]; then
  protected_file "$AUTH_HEADER_FILE" yes
  # Never forward a private GitHub credential to a freely configurable host.
  for url in "$INSTALLER_URL" "$SIGNATURE_URL"; do
    [[ "$url" =~ ^https://api\.github\.com/repos/ViSka-glitch/Security-Alert-Analyzer/releases/assets/[0-9]+$ ]] || fail "Authentifizierter Abruf ist nur für private SAA-Release-Assets erlaubt."
  done
  [[ "$(wc -l < "$AUTH_HEADER_FILE")" == 1 ]] || fail "Zugangsdatei muss genau eine Headerzeile enthalten."
  LC_ALL=C grep -Eq '^Authorization: Bearer [A-Za-z0-9_]+$' "$AUTH_HEADER_FILE" || fail "Ungültiges Zugangsdateiformat."
fi

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
if $VERIFY_ONLY; then
  echo "Download, SHA-256 und Signatur bestätigt. Installer nicht gestartet (--verify-only)."
  exit 0
fi
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
