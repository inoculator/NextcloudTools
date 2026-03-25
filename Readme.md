# GenAI Disclaimer
ReadMe.md created by AI  

# Human Disclaimer
Der Code wird bereitgestellt "as-is". Es wird keinerlei Gewährleistung gegeben. Weder auf korrekte Funktion, noch auf Schäden, welche durch die Nutzung entstehen. Es wird davon abgeraten, den Code in produktiven Systemen zu verwenden!

---

# 🗂️ restore-ncfile.ps1  
Ein PowerShell‑Script zur Wiederherstellung gelöschter Nextcloud‑Dateien oder Ordner aus der Trashbin‑Struktur über Datenbank‑ und Dateisystemabgleich auf einem Linux Server.  
Erzeugt die laufzeit Funktion "restore-ncfile".  

### Anpassungen
Innerhalb der Funktion muss ein Wert vor Benutzung angepasst werden:  
```
$ncBaseDir = "[put Nextcloud base dir in here]" #eg: "/var/www/nextcloud"
```

## 🧩 Überblick  
`restore-ncfile` stellt gelöschte Dateien oder Ordner eines Nextcloud‑Benutzers wieder her, indem es:

- die Nextcloud‑Datenbank (`oc_files_trash`) nach passenden Einträgen durchsucht  
- die zugehörigen Trashbin‑Objekte im Dateisystem lokalisiert  
- Dateien oder Ordner an ihren ursprünglichen Speicherort zurückverschiebt  
- optional vorhandene Dateien überschreibt  
- die Datenbankeinträge entfernt  
- Dateirechte korrigiert  
- einen gezielten `occ files:scan` für den betroffenen Pfad ausführt  
- mit `-whatif` einen vollständigen Simulationsmodus bietet  

Das Script ist ideal für Administratoren, die gezielt einzelne Dateien oder ganze Objektgruppen wiederherstellen möchten, ohne manuell im Trashbin suchen zu müssen.

---

## 🚀 Features  
- Wiederherstellung von **Dateien und Ordnern**  
- Filterung nach:
  - Benutzer (`-ncUser`)
  - Zeitfenster (`-DateAfter`, `-DateBefore`)
  - Ursprungs‑Pfad (`-location`, Regex)
  - Dateiname (`-itemName`, Regex)
- Sicheres Regex‑Handling (Escape + Validierung)
- Optionales Überschreiben existierender Dateien/Ordner (`-force`)
- Vollständiger Simulationsmodus (`-whatif`)
- Automatische Bereinigung der Datenbank
- Automatische Rechtekorrektur (`chown`)
- Automatischer OCC‑Rescan für den betroffenen Pfad
- Ausführliche Debug‑Ausgabe über `-Verbose`

---

## 📂 Voraussetzungen  
- PowerShell (Core oder Windows PowerShell)  
- Nextcloud‑Server mit Zugriff auf:
  - Nextcloud‑Datenverzeichnis  
  - Nextcloud‑Datenbank  
- PowerShell‑Modul **SimplySQL**  
- Ausreichende Rechte für:
  - Dateisystemzugriffe  
  - `chown`  
  - `sudo -u www-data php occ …`  

---

## 🔧 Parameter  
| Parameter | Pflicht | Beschreibung |
|----------|---------|--------------|
| `-ncUser` | ✔️ | Nextcloud‑Benutzer, dessen gelöschte Dateien/Ordner wiederhergestellt werden sollen |
| `-DateAfter` | ❌ | Untere Zeitgrenze (Standard: jetzt − 2 Tage) |
| `-DateBefore` | ❌ | Obere Zeitgrenze (Standard: jetzt) |
| `-location` | ❌ | Regex für ursprünglichen Pfad (Standard: `.*`) |
| `-itemName` | ❌ | Regex für Dateinamen (Standard: `.*`) |
| `-force` | ❌ | Überschreibt existierende Dateien/Ordner |
| `-whatif` | ❌ | Simuliert alle Aktionen ohne Änderungen |

---

## ▶️ Nutzung  
### Beispiel 1 — Datei anhand des Namens wiederherstellen  
```powershell
./restore-ncfile -ncUser alice -itemName "bericht.pdf"
```

### Beispiel 2 — Dateien aus einem bestimmten Ordner wiederherstellen  
```powershell
./restore-ncfile -ncUser bob -location "Documents/Projekte"
```

### Beispiel 3 — Wiederherstellung eines Zeitfensters  
```powershell
./restore-ncfile -ncUser alice -DateAfter "2024-01-01" -DateBefore "2024-01-03"
```

### Beispiel 4 — Existierende Dateien überschreiben  
```powershell
./restore-ncfile -ncUser alice -itemName "scan_.*" -force
```

### Beispiel 5 — Simulation ohne Änderungen  
```powershell
./restore-ncfile -ncUser alice -location "Fotos" -whatif
```

---

## ⚙️ Funktionsweise (Kurzfassung)  
1. Einlesen der Nextcloud Konfiguration  
2. Verbindung zur Nextcloud‑Datenbank  
3. SQL‑Abfrage der passenden Trash‑Einträge  
4. Zuordnung zu den Dateien im Trashbin‑Dateisystem  
5. Validierung:
   - Datei/Ordner existiert  
   - Regex gültig  
6. Wiederherstellung:
   - Zielpfad erzeugen  
   - Datei/Ordner verschieben  
   - Optional überschreiben  
7. Bei echtem Lauf (`-whatif` **nicht** gesetzt):
   - DB‑Eintrag löschen  
   - Rechte korrigieren  
   - OCC‑Rescan für den betroffenen Pfad  

---

## ⚠️ Hinweise  
- Das Script setzt voraus, dass Trashbin‑Objekte dem Muster `id.d<timestamp>` folgen.  
- `-whatif` verhindert **alle** Änderungen an DB, Dateisystem und OCC.  
- Das Script arbeitet ausschließlich serverseitig.  

---

## 🤝 Mitwirken  
Pull Requests, Bug Reports und Feature‑Vorschläge sind willkommen.  

---

## 📜 Lizenz  
GNU General Public License (GPL)

