# Security Alert Analyzer – Bootstrapper

Öffentlicher Einstiegspunkt für die geplante geführte SAA-Serverinstallation.
Dieses Repository enthält nur den Bootstrapper und diese Anleitung. Die Anwendung
Security Alert Analyzer und ihr Quellcode bleiben in einem separaten privaten Repository.

## Aktueller Stand

**Noch kein vollständiger Einzeiler für eine leere VM und keine Produktivfreigabe.**
Der Bootstrapper lädt einen ausdrücklich konfigurierten Installer über HTTPS,
prüft dessen erwarteten SHA-256-Wert und eine verpflichtende getrennte OpenSSL-Signatur
mit einem vorab vertrauenswürdig installierten öffentlichen Schlüssel. Erst danach startet er den Installer. Für die geführten
Eingaben wird das Terminal verwendet, auch wenn das Skript über eine Pipe geladen wird.

Zum Laden bleiben Linux, Bash, root beziehungsweise sudo und ein Downloadwerkzeug
erforderlich. Fehlende Prüfwerkzeuge (curl, OpenSSL, Coreutils und CA-Zertifikate)
kann der Bootstrapper nach Bestätigung aus den eingerichteten Paketquellen installieren.
Das Linux-Betriebssystem und root-Zugang werden nicht durch das Skript eingerichtet.

Der weiterentwickelte private Installer bietet jetzt Hostvorbereitung an: Git,
Python 3, SSH-Client, Terminaldialoge, Docker/Compose und ein Betriebskonto ohne
zusätzliche sudo-/Docker-Gruppenrechte. Ubuntu 24.04 verwendet Ubuntu-Pakete;
RHEL 9/10 benötigt zuvor von der IT freigegebene Docker-CE-Paketquellen und Subscription.
Vorhandenes Podman/Containerd wird nicht automatisch ersetzt; bestehendes Docker
ohne Compose-Plugin erfordert eine manuelle Ergänzung aus derselben Paketquelle.
Es gibt noch keine praktische Neuinstallationsabnahme dieser Automatisierung.

Der Assistent kann einen Deploy-Key erzeugen und zeigt nur dessen öffentlichen Teil.
Die einmalige Freigabe im privaten GitHub-Repository erfolgt durch den Eigentümer.
Anschließend wird der lesende Zugriff geprüft. Private Schlüssel bleiben auf dem Server.

## Konfiguration

- `SAA_INSTALLER_URL`: vom Betreiber freigegebene HTTPS-Adresse des Installers.
- `SAA_INSTALLER_SHA256`: vollständige, unabhängig geprüfte SHA-256-Prüfsumme.
- `SAA_INSTALLER_SIGNATURE_URL`: HTTPS-Adresse der binären SHA-256-Signatur.
- `SAA_INSTALLER_PUBLIC_KEY`: lokaler PEM-Prüfschlüssel, Standard `/etc/saa/installer-public.pem`.
- `SAA_INSTALLER_AUTH_HEADER_FILE`: optionaler kanonischer Dateipfad mit genau einer
  Zeile `Authorization: Bearer <TOKEN>` samt abschließendem Zeilenumbruch.
  Nur root darf die Datei lesen (Modus 0600). Schlüssel und sämtliche Elternverzeichnisse
  müssen root gehören und dürfen nicht gruppen- oder weltweit beschreibbar sein.
  Authentifizierte URLs sind ausschließlich GitHub-Release-Asset-API-Adressen des
  privaten Produktrepositorys: `https://api.github.com/repos/ViSka-glitch/Security-Alert-Analyzer/releases/assets/<ID>`.
- `--dry-run`: reicht den Vorprüfungsmodus an den Installer weiter.
- `--non-interactive`: benötigt extern vorbereitete Konfiguration und Secrets.
- `--prepare-host`: Hostvorbereitung ausdrücklich anfordern; fehlende Voraussetzungen
  aktivieren sie bei `install` auch automatisch.
- `--confirm-host-changes`: Paket-/Dienst-/Kontoänderungen ohne Rückfrage erlauben;
  im nichtinteraktiven Modus erforderlich. `--dry-run` installiert keine Pakete.

Es gibt noch keine veröffentlichte freigegebene Installeradresse mit Signaturnachweis.
Deshalb wird hier bewusst kein vermeintlich fertiger Installations-Einzeiler angegeben.
Ein anonymer Raw-Link auf ein privates GitHub-Repository funktioniert nicht.
Ein lesender, auf das Produktrepository begrenzter Zugang muss separat auf dem
Zielserver provisioniert werden. Keine Tokenwerte in Befehlsargumenten übergeben.
Der Git-Deploy-Key für den späteren Produktcheckout ist ein eigener Zugang.

## Sicherheit und nächste Schritte

Keine Tokens oder Kennwörter in URLs, Shell-Historien, Issues oder dieses Repository
kopieren. Ein SHA-256-Vergleich allein ersetzt keine Signaturprüfung: Wird der
Bootstrapper manipuliert, könnte auch sein erwarteter Hash verändert werden.
Das Laden eines Skripts direkt in eine Root-Shell setzt Vertrauen in die gesamte
Auslieferungskette voraus. Vor Produktiveinsatz fehlen insbesondere ein versioniertes,
signiertes Release, ein vertrauenswürdiger Prüfschlüssel und die Neuinstallations-,
Update- und Wiederherstellungsabnahme. Red Hat ist noch nicht abgenommen.

**Vertrauensgrenze:** Der lokale Releasegenerator bindet die signierte Installerdatei
an einen vollständigen Git-Commit. Die unverpackte Entwicklerfassung folgt weiterhin
einem Branch und ist kein signiertes Release. Containerimages, Paketquellen,
Vertrauensanker und die spätere Updateausführung benötigen eigene Betriebsfreigaben.
Ein echter signierter Release ist noch nicht veröffentlicht.

Die 22 isolierten Prüfungen verwenden Wegwerf-Schlüssel, simulierte Downloads
und Paket-/Kontopläne ohne Systemänderungen.
Sie sind keine Abnahme eines echten privaten Downloads oder einer Neuinstallation.

Der Betreiber muss als Nächstes den authentifizierten Bezug des privaten Installers
beziehungsweise ein freigegebenes Releasepaket bereitstellen. Anschließend wird daraus
ein kurzer, getesteter Installationsaufruf erstellt.

Öffentliche Sichtbarkeit dieses Repositorys ist keine Open-Source-Lizenzierung des
SAA-Produkts. Es wird hier keine zusätzliche Lizenz erteilt.
