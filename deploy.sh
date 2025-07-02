#!/bin/bash

# Simple Hetzner Cloud Server Deployment Script
# Usage: ./deploy.sh <server-name> [server-type] [location]

set -euo pipefail

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Standardwerte
DEFAULT_SERVER_TYPE="cx22"
DEFAULT_LOCATION="nbg1"
DEFAULT_IMAGE="ubuntu-24.04"

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

# Prüfen ob hcloud installiert ist
if ! command -v hcloud &> /dev/null; then
    print_error "hcloud CLI ist nicht installiert!"
    echo "Installation: brew install hcloud (macOS) oder https://github.com/hetznercloud/cli"
    exit 1
fi

# Prüfen ob cloud-config.yaml existiert
if [ ! -f "cloud-config.yaml" ]; then
    print_error "cloud-config.yaml nicht gefunden!"
    exit 1
fi

# Parameter prüfen
if [ $# -lt 1 ]; then
    echo "Usage: $0 <server-name> [server-type] [location]"
    echo "  server-name: Name des Servers"
    echo "  server-type: Typ des Servers (default: $DEFAULT_SERVER_TYPE)"
    echo "  location: Datacenter Location (default: $DEFAULT_LOCATION)"
    echo ""
    echo "Verfügbare Server-Typen:"
    echo "  cx22  - 2 vCPU, 4 GB RAM, 40 GB Disk"
    echo "  cx32  - 4 vCPU, 8 GB RAM, 80 GB Disk"
    echo "  cx42  - 8 vCPU, 16 GB RAM, 160 GB Disk"
    echo ""
    echo "Verfügbare Locations:"
    echo "  nbg1  - Nürnberg"
    echo "  fsn1  - Falkenstein"
    echo "  hel1  - Helsinki"
    exit 1
fi

# Parameter setzen
SERVER_NAME="$1"
SERVER_TYPE="${2:-$DEFAULT_SERVER_TYPE}"
LOCATION="${3:-$DEFAULT_LOCATION}"

print_info "Server-Deployment wird vorbereitet..."
echo "  Name: $SERVER_NAME"
echo "  Typ: $SERVER_TYPE"
echo "  Location: $LOCATION"
echo "  Image: $DEFAULT_IMAGE"
echo ""

# Bestätigung
read -p "Möchten Sie fortfahren? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_warning "Deployment abgebrochen."
    exit 0
fi

# SSH-Key Name (wird aus dem cloud-config extrahiert)
SSH_KEY_NAME="jr-gmbh@hetzner"

# Prüfen ob SSH-Key in Hetzner Cloud existiert
if ! hcloud ssh-key list | grep -q "$SSH_KEY_NAME"; then
    print_warning "SSH-Key '$SSH_KEY_NAME' nicht in Hetzner Cloud gefunden."
    echo "Bitte fügen Sie den Key mit folgendem Befehl hinzu:"
    echo "hcloud ssh-key create --name \"$SSH_KEY_NAME\" --public-key-from-file ~/.ssh/id_ed25519.pub"
    exit 1
fi

# Server erstellen
print_info "Erstelle Server '$SERVER_NAME'..."

if hcloud server create \
    --name "$SERVER_NAME" \
    --type "$SERVER_TYPE" \
    --image "$DEFAULT_IMAGE" \
    --location "$LOCATION" \
    --ssh-key "$SSH_KEY_NAME" \
    --user-data-from-file cloud-config.yaml; then
    
    print_info "Server wurde erfolgreich erstellt!"
    
    # Warte kurz, bis der Server bereit ist
    sleep 5
    
    # Server-Info abrufen
    SERVER_INFO=$(hcloud server describe "$SERVER_NAME" -o json)
    SERVER_IP=$(echo "$SERVER_INFO" | grep -o '"ipv4":[^,]*' | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+')
    
    print_info "Server-Details:"
    echo "  Name: $SERVER_NAME"
    echo "  IP: $SERVER_IP"
    echo "  SSH-Port: 2222"
    echo ""
    
    print_info "Warte auf Server-Initialisierung (ca. 2-3 Minuten)..."
    echo "Der Server führt gerade das cloud-init Setup durch."
    echo ""
    
    print_info "SSH-Verbindung nach Setup:"
    echo "  ssh -p 2222 iosko@$SERVER_IP"
    echo ""
    
    # SSH-Config Eintrag vorschlagen
    print_info "Empfohlener ~/.ssh/config Eintrag:"
    cat << EOF
Host $SERVER_NAME
    HostName $SERVER_IP
    Port 2222
    User iosko
    ForwardAgent yes
EOF
    
else
    print_error "Server-Erstellung fehlgeschlagen!"
    exit 1
fi