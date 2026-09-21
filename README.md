# Security Alert Analyzer – Bootstrapper

Öffentlicher Einstiegspunkt für die geplante geführte SAA-Serverinstallation.
Dieses Repository enthält nur den Bootstrapper und diese Anleitung. Die Anwendung
Security Alert Analyzer und ihr Quellcode bleiben in einem separaten privaten Repository.

## Aktueller Stand

**Noch kein vollständiger Einzeiler für eine leere VM und keine Produktivfreigabe.**
Der Bootstrapper lädt den vorbelegten signierten Testinstaller über HTTPS,
prüft dessen erwarteten SHA-256-Wert und eine verpflichtende getrennte OpenSSL-Signatur
mit dem eingebetteten oder einem separat vertrauenswürdig installierten öffentlichen Schlüssel. Erst danach startet er den Installer. Für die geführten
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

### Fest versionierter Aufruf: ausschließlich prüfen

In einer interaktiven Bash-Sitzung auf Linux ausführen. Der Download muss vollständig
erfolgreich sein, bevor Bash startet. Dies ist ein Testzugang, keine Produktivfreigabe.
Prüfwerkzeuge müssen für diesen Modus bereits vorhanden sein; es werden keine Pakete installiert.

```bash
bash -c 'set -e; f=$(mktemp); trap '\''rm -f -- "$f"'\'' EXIT; curl --fail --silent --show-error --location --proto "=https" --proto-redir "=https" --connect-timeout 15 --max-time 120 https://raw.githubusercontent.com/ViSka-glitch/Security-Alert-Analyzer-Installer/c86a3d21af327918ee6dae3bda39e7165d011594/bootstrap_server.sh -o "$f"; sudo bash "$f" --verify-only'
```

Das GitHub-Token erst in der verdeckten Abfrage eingeben, nicht in diesen Befehl.
Erwartet: `Download, SHA-256 und Signatur bestätigt. Installer nicht gestartet (--verify-only).`
Bei HTTP 401/403/404 Zugang und Sichtbarkeit des privaten Entwurfs prüfen; nicht
Signaturprüfung abschalten oder pauschal weitergehende Kontorechte vergeben.

### Geführter Testeinstieg ohne vorbereitete Dateien

Der Bootstrapper enthält jetzt die beiden Asset-Adressen, den erwarteten Hash und den
öffentlichen Prüfschlüssel für `installer-test-555d59a`. Ohne Zugangsdatei fragt er das
GitHub-Token verdeckt über das Terminal ab. Das ist **keine OAuth-/Browseranmeldung**.
Der Tokenwert landet nur kurzzeitig in einer root-geschützten Datei unter `/run` und
wird beim Beenden entfernt; nicht als Argument oder Umgebungsvariable übergeben.
Ein gültiger GitHub-Zugang muss vorhanden sein. Der Testrelease ist noch ein Entwurf;
der Abruf mit einem ausschließlich lesenden Installationskonto ist nicht abgenommen.

Vorher kein Betriebskonto und keine sudo-Regeln für `saa` anlegen. Nach erfolgreicher
Prüfung übernimmt der private Installer die bestätigte Hostvorbereitung. Die einmalige
GitHub-Freigabe des erzeugten Deploy-Keys bleibt notwendig. Für reine Prüfung
`--verify-only` verwenden: kein Installerstart und keine Paketinstallation.

Der mitgelieferte öffentliche Schlüssel vermeidet eine zusätzliche Dateiübertragung,
ist aber **kein unabhängig bezogener Vertrauensanker**. Deshalb einen geprüften festen
Bootstrap-Commit verwenden. Der private Signierschlüssel ist niemals enthalten.

- `SAA_INSTALLER_URL`: vom Betreiber freigegebene HTTPS-Adresse des Installers.
- `SAA_INSTALLER_SHA256`: vollständige, unabhängig geprüfte SHA-256-Prüfsumme.
- `SAA_INSTALLER_SIGNATURE_URL`: HTTPS-Adresse der binären SHA-256-Signatur.
- `SAA_INSTALLER_PUBLIC_KEY`: optionaler lokaler PEM-Prüfschlüssel statt des eingebetteten Schlüssels.
- `SAA_INSTALLER_AUTH_HEADER_FILE`: optionaler kanonischer Dateipfad mit genau einer
  Zeile `Authorization: Bearer <TOKEN>` samt abschließendem Zeilenumbruch.
  Nur root darf die Datei lesen (Modus 0600). Schlüssel und sämtliche Elternverzeichnisse
  müssen root gehören und dürfen nicht gruppen- oder weltweit beschreibbar sein.
  Authentifizierte URLs sind ausschließlich GitHub-Release-Asset-API-Adressen des
  privaten Produktrepositorys: `https://api.github.com/repos/ViSka-glitch/Security-Alert-Analyzer/releases/assets/<ID>`.
- `--dry-run`: reicht den Vorprüfungsmodus an den Installer weiter.
- `--verify-only`: lädt und prüft Installer und Signatur, startet den Installer aber
  niemals. Fehlende Prüfwerkzeuge führen zum Abbruch statt zu Paketinstallation.
  Netzwerkzugriffe und kurzlebige temporäre Dateien bleiben erforderlich.
- `--non-interactive`: benötigt extern vorbereitete Konfiguration und Secrets.
- `--prepare-host`: Hostvorbereitung ausdrücklich anfordern; fehlende Voraussetzungen
  aktivieren sie bei `install` auch automatisch.
- `--confirm-host-changes`: Paket-/Dienst-/Kontoänderungen ohne Rückfrage erlauben;
  im nichtinteraktiven Modus erforderlich. `--dry-run` installiert keine Pakete.

Es gibt einen signierten privaten Testrelease-Entwurf mit vorbelegten Asset-Adressen,
aber noch keine produktiv freigegebene Auslieferung oder frische Installationsabnahme.
Ein anonymer Raw-Link auf ein privates GitHub-Repository funktioniert nicht.
Ein passender GitHub-Zugang muss vorhanden sein; der Token kann verdeckt eingegeben
werden. Keine Tokenwerte in Befehlsargumenten übergeben. Der separate lesende Zugang
ist noch nicht abgenommen; dem Testrelease-Entwurf nicht blind weitergehende Rechte geben.
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
Ein signierter privater Testrelease-Entwurf ist vorhanden, kein freigegebener Produktrelease.

Die 26 isolierten Prüfungen verwenden Wegwerf-Schlüssel, simulierte Downloads
und Paket-/Kontopläne ohne Systemänderungen.
Sie sind keine Abnahme eines echten privaten Downloads oder einer Neuinstallation.
Zusätzlich ist der echte Nur-Prüfen-Download mit eingebetteten Releasewerten und dem
vorhandenen Herausgeberzugang bestanden. Die Tokenabfrage ist im Pseudoterminal mit
Testtoken auf unterdrücktes Echo geprüft. Ein neuer lesender Zugang bleibt ungeprüft.

Als Nächstes stehen der Test mit einem separaten eingeschränkten Zugang und die frische
VM-Installationsabnahme an. `--help` zeigt die Aufrufhilfe ohne Download. Nur die
dokumentierten Optionen werden akzeptiert; `update` und `uninstall` sind über den
Bootstrapper ausdrücklich gesperrt und bleiben eigene kontrollierte Betriebsabläufe.

Öffentliche Sichtbarkeit dieses Repositorys ist keine Open-Source-Lizenzierung des
SAA-Produkts. Es wird hier keine zusätzliche Lizenz erteilt.
