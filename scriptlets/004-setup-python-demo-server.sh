#!/bin/bash

# Python Demo Server Setup (Dustbowl Initial)
# Usage: ./004-setup-python-demo-server.sh

set -euo pipefail

# Farben für Output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Funktion für farbige Ausgabe
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_info "Python Demo Server Setup startet..."
echo ""

# Root-Rechte prüfen
if [ "$EUID" -ne 0 ]; then 
    print_error "Dieses Script muss mit sudo ausgeführt werden!"
    exit 1
fi

# Variablen
VENV_PATH="/home/iosko/python-demo-server"
SERVICE_NAME="python-demo-server"
APP_USER="iosko"

# Script-Verzeichnis ermitteln
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
APP_SOURCE="${SCRIPT_DIR}/../python-app/app.py"

# Python-Pakete installieren
print_info "Installiere Python-Pakete..."
apt update
apt install -y python3-pip python3-venv

# Prüfen ob app.py existiert
if [ ! -f "$APP_SOURCE" ]; then
    print_error "app.py nicht gefunden: $APP_SOURCE"
    exit 1
fi

# Virtual Environment erstellen (als iosko User)
print_info "Erstelle Virtual Environment..."
if [ -d "$VENV_PATH" ]; then
    print_warning "Virtual Environment existiert bereits, wird überschrieben..."
    rm -rf "$VENV_PATH"
fi

# Als iosko User ausführen
sudo -u $APP_USER python3 -m venv "$VENV_PATH"

# Python-Pakete im venv installieren
print_info "Installiere Python-Pakete im Virtual Environment..."
sudo -u $APP_USER "$VENV_PATH/bin/pip" install --upgrade pip
sudo -u $APP_USER "$VENV_PATH/bin/pip" install fastapi uvicorn yfinance matplotlib

# App kopieren
print_info "Kopiere Anwendung..."
cp "$APP_SOURCE" "$VENV_PATH/app.py"
chown $APP_USER:$APP_USER "$VENV_PATH/app.py"

# Systemd Service erstellen
print_info "Erstelle systemd Service..."
cat > /etc/systemd/system/${SERVICE_NAME}.service << EOF
[Unit]
Description=Python Demo Server (Dustbowl Initial)
After=network.target

[Service]
Type=simple
User=$APP_USER
Group=$APP_USER
WorkingDirectory=$VENV_PATH
Environment="PATH=$VENV_PATH/bin"
ExecStart=$VENV_PATH/bin/uvicorn app:app --host 127.0.0.1 --port 8000
Restart=always
RestartSec=10

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=$SERVICE_NAME

# Security
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

# Service aktivieren und starten
print_info "Aktiviere und starte Service..."
systemctl daemon-reload
systemctl enable ${SERVICE_NAME}.service
systemctl start ${SERVICE_NAME}.service

# Warte kurz und prüfe Status
sleep 2
if systemctl is-active --quiet ${SERVICE_NAME}; then
    print_info "Service läuft erfolgreich!"
else
    print_error "Service konnte nicht gestartet werden!"
    print_info "Prüfe Logs mit: journalctl -u ${SERVICE_NAME} -n 50"
    exit 1
fi

# Test ob Port 8000 erreichbar ist
print_info "Teste Erreichbarkeit..."
sleep 3
if curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8000/ | grep -q "200\|404\|422"; then
    print_info "Server antwortet auf Port 8000!"
else
    print_warning "Server antwortet noch nicht auf Port 8000"
    print_info "Das kann normal sein beim ersten Start"
fi

print_info "Python Demo Server Setup abgeschlossen!"
echo ""
echo "Status:"
echo "- Virtual Environment: $VENV_PATH"
echo "- Service Name: ${SERVICE_NAME}"
echo "- Port: 8000 (nur localhost)"
echo "- User: $APP_USER"
echo ""
echo "Nützliche Befehle:"
echo "- Status: systemctl status ${SERVICE_NAME}"
echo "- Logs: journalctl -u ${SERVICE_NAME} -f"
echo "- Neustart: systemctl restart ${SERVICE_NAME}"
echo "- Stoppen: systemctl stop ${SERVICE_NAME}"
echo ""
echo "Die App ist erreichbar unter:"
echo "https://devsandbox.ihre-domain.xyz/dustbowl-initial/"