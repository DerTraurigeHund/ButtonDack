# ButtonDack 🐾

> Remote control für deinen PC — mit Spotify Now-Playing, Hotkeys und Commands.
> Moderner Rewrite des ursprünglichen [ButtonDack](https://github.com/DerTraurigeHund/ButtonDack) Projekts.

## 🎯 Features

- **Button Grid** auf deinem Tablet/Handy — steuere deinen PC übers lokale Netzwerk
- **Spotify Integration** — zeige aktuellen Track + Album Cover live an
- **Hotkeys** — simuliere beliebige Tastenkombinationen
- **Shell Commands** — führe beliebige Befehle aus (Apps starten, System steuern, ...)
- **Profile** — organisiere Buttons in Gruppen (System, Media, Apps, ...)
- **Echtzeit** — WebSocket Kommunikation, kein manuelles Neuladen

## 🏗️ Architecture

```
┌────────────────────┐    WebSocket     ┌──────────────────────┐
│  Flutter Mobile App │◄────────────────►│  Go Backend Daemon   │
│  (Tablet/Handy)     │                  │  (buttondackd)       │
│                     │    REST API      │                      │
│  • Button Grid      │◄────────────────►│  • Command Runner    │
│  • Spotify Now      │                  │  • Hotkey Engine     │
│  • Profile Switch   │                  │  • Spotify OAuth     │
└──────────────────────┘                  │  • Spotify Polling  │
                                          │  • Config Manager   │
┌──────────────────────┐  REST API        └──────────────────────┘
│  Settings Desktop App│◄────────────────►
│  (Flutter Desktop)    │
│                      │
│  • Button Editor     │
│  • Profile Manager   │
│  • Spotify Auth      │
│  • Daemon Control    │
└──────────────────────┘
```

## 🚀 Quick Start

### Daemon

```bash
# Daemon starten (Linux)
./daemon/build/buttondackd

# Oder mit systemd
sudo cp install/buttondack.service /etc/systemd/system/
sudo systemctl enable --now buttondackd
```

Standard-Port: **42069** — erreichbar unter `http://<dein-pc>:42069`

### Config

Die Config liegt unter `~/.config/buttondack/config.yaml` und wird beim ersten Start automatisch mit Defaults angelegt.

## 📱 Apps bauen

### Mobile App (Android/iOS)

```bash
cd mobile/buttondack_mobile
flutter run          # Startet auf connected device
flutter build apk    # APK bauen
flutter build ios    # iOS build (macOS needed)
```

### Settings App (Windows/Linux)

```bash
cd app/buttondack_settings
flutter run -d linux     # Linux Desktop
flutter build linux      # Linux Binary
flutter build windows    # Windows Binary (cross-compile)
```

## ⚙️ Daemon Build

```bash
cd daemon
make build                 # Linux amd64
make build-windows         # Windows amd64 (cross)
make build-linux-arm64     # ARM64 (z.B. Raspberry Pi)
```

### Packages

```bash
sudo bash install/build-packages.sh
# Erzeugt .deb und .pkg.tar.zst in install/pkg/
```

## 🔑 Spotify Setup

1. Gehe zu [Spotify Developer Dashboard](https://developer.spotify.com/dashboard)
2. Erstelle eine App
3. Kopiere **Client ID** und **Client Secret**
4. Trage sie in `~/.config/buttondack/config.yaml` ein:
   ```yaml
   spotify:
     client_id: "deine-client-id"
     client_secret: "dein-client-secret"
     enabled: true
   ```
5. Starte den Daemon neu
6. Authorisiere über die Settings App oder per `POST /api/spotify/auth`

## 📡 API

| Endpunkt | Methode | Beschreibung |
|----------|---------|-------------|
| `/ws` | WebSocket | Echtzeit-Kommunikation |
| `/api/health` | GET | Server-Status |
| `/api/config` | GET | Config abrufen |
| `/api/config/update` | POST | Config speichern |
| `/api/action` | POST | Button-Aktion ausführen |
| `/api/spotify/auth` | POST | Spotify Auth starten |
| `/api/spotify/poll` | GET | Aktuellen Track abrufen |

## 🛠️ Tech Stack

| Komponente | Technologie |
|------------|-------------|
| Backend | Go (gorilla/websocket, yaml.v3) |
| Mobile App | Flutter (Provider, web_socket_channel) |
| Desktop App | Flutter Desktop |
| Config | YAML |
| Spotify API | REST (OAuth Device Code Grant) |

## 📁 Projektstruktur

```
buttondack/
├── daemon/                    # Go Backend
│   ├── cmd/buttondackd/      # Entrypoint
│   ├── internal/
│   │   ├── server/           # WebSocket + REST
│   │   ├── actions/          # Command + Hotkey Exec
│   │   ├── spotify/          # OAuth + Polling
│   │   └── config/           # Config Manager
│   ├── config.yaml           # Beispiel-Config
│   └── Makefile
├── app/buttondack_settings/   # Flutter Desktop Settings
├── mobile/buttondack_mobile/  # Flutter Mobile App
├── install/                   # Pakete, systemd, Skripte
└── docs/
```
