# Security Alert Analyzer – Bootstrapper

Öffentlicher Einstiegspunkt für die geplante geführte SAA-Serverinstallation.
Dieses Repository enthält nur den Bootstrapper und diese Anleitung. Die Anwendung
Security Alert Analyzer und ihr Quellcode bleiben in einem separaten privaten Repository.

## Aktueller Stand

**Noch kein vollständiger Einzeiler für eine leere VM und keine Produktivfreigabe.**
Der Bootstrapper lädt einen ausdrücklich konfigurierten Installer über HTTPS,
prüft dessen erwarteten SHA-256-Wert und startet ihn erst danach. Für die geführten
Eingaben wird das Terminal verwendet, auch wenn das Skript über eine Pipe geladen wird.

Erforderlich sind derzeit Linux, sudo/root, curl, sha256sum und für den eigentlichen
Installer zusätzlich Git, Python 3, Docker Engine, Compose v2, ein vorbereitetes
Betriebskonto und lesender Zugriff auf das private Produktrepository.
Die automatische Einrichtung dieser Voraussetzungen ist noch nicht enthalten.

## Konfiguration

- `SAA_INSTALLER_URL`: vom Betreiber freigegebene HTTPS-Adresse des Installers.
- `SAA_INSTALLER_SHA256`: vollständige, unabhängig geprüfte SHA-256-Prüfsumme.
- `--dry-run`: reicht den Vorprüfungsmodus an den Installer weiter.
- `--non-interactive`: benötigt extern vorbereitete Konfiguration und Secrets.

Es gibt noch keine veröffentlichte freigegebene Installeradresse mit Signaturnachweis.
Deshalb wird hier bewusst kein vermeintlich fertiger Installations-Einzeiler angegeben.
Ein anonymer Raw-Link auf ein privates GitHub-Repository funktioniert nicht.

## Sicherheit und nächste Schritte

Keine Tokens oder Kennwörter in URLs, Shell-Historien, Issues oder dieses Repository
kopieren. Ein SHA-256-Vergleich allein ersetzt keine Signaturprüfung: Wird der
Bootstrapper manipuliert, könnte auch sein erwarteter Hash verändert werden.
Das Laden eines Skripts direkt in eine Root-Shell setzt Vertrauen in die gesamte
Auslieferungskette voraus. Vor Produktiveinsatz fehlen insbesondere ein versioniertes,
signiertes Release, ein vertrauenswürdiger Prüfschlüssel und die Neuinstallations-,
Update- und Wiederherstellungsabnahme. Red Hat ist noch nicht abgenommen.

Der Betreiber muss als Nächstes den authentifizierten Bezug des privaten Installers
beziehungsweise ein freigegebenes Releasepaket bereitstellen. Anschließend wird daraus
ein kurzer, getesteter Installationsaufruf erstellt.

Öffentliche Sichtbarkeit dieses Repositorys ist keine Open-Source-Lizenzierung des
SAA-Produkts. Es wird hier keine zusätzliche Lizenz erteilt.
