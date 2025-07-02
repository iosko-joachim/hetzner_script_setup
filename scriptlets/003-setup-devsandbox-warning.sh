#!/bin/bash

# DevSandbox Warning Page Setup
# Usage: ./003-setup-devsandbox-warning.sh <domain>
# Beispiel: ./003-setup-devsandbox-warning.sh jr-gmbh.ch

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

# Parameter prüfen
if [ $# -lt 1 ]; then
    print_error "Domain fehlt!"
    echo "Usage: $0 <domain>"
    echo "Beispiel: $0 jr-gmbh.ch"
    exit 1
fi

DOMAIN="$1"

print_info "DevSandbox Warning Page Setup für Domain: $DOMAIN"
echo ""

# Root-Rechte prüfen
if [ "$EUID" -ne 0 ]; then 
    print_error "Dieses Script muss mit sudo ausgeführt werden!"
    exit 1
fi

# Script-Verzeichnis ermitteln
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
WARNING_SOURCE="${SCRIPT_DIR}/../devsandbox-warning/index.html"
WARNING_DEST="/var/www/devsandbox-warning"

# Prüfen ob Source-Datei existiert
if [ ! -f "$WARNING_SOURCE" ]; then
    print_error "Warning-HTML nicht gefunden: $WARNING_SOURCE"
    exit 1
fi

# Zielverzeichnis erstellen falls nicht vorhanden
if [ ! -d "$WARNING_DEST" ]; then
    print_info "Erstelle Verzeichnis $WARNING_DEST..."
    mkdir -p "$WARNING_DEST"
fi

# HTML kopieren und Domain einsetzen
print_info "Kopiere und passe Warning-Page an..."
sed "s|https://jr-gmbh.ch|https://$DOMAIN|g" "$WARNING_SOURCE" > "$WARNING_DEST/index.html"

# Link-Text auch anpassen (jr-gmbh.ch -> $DOMAIN)
sed -i "s|>jr-gmbh.ch<|>$DOMAIN<|g" "$WARNING_DEST/index.html"

# Berechtigungen setzen
print_info "Setze Berechtigungen..."
chown -R www-data:www-data "$WARNING_DEST"
chmod -R 755 "$WARNING_DEST"

# Nginx neuladen (falls Änderungen)
print_info "Lade Nginx neu..."
systemctl reload nginx || print_warning "Nginx reload fehlgeschlagen (möglicherweise noch nicht installiert)"

print_info "DevSandbox Warning Page Setup abgeschlossen!"
echo ""
echo "Die Warnseite ist erreichbar unter:"
echo "https://devsandbox.$DOMAIN/"
echo ""
echo "Der Link verweist auf: https://$DOMAIN"