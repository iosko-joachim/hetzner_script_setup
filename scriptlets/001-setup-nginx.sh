#!/bin/bash

# Nginx Setup mit SSL (Let's Encrypt)
# Usage: ./001-setup-nginx.sh <domain>
# Beispiel: ./001-setup-nginx.sh jr-gmbh.ch

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
EMAIL="richter.klaus.joachim@gmail.com"

print_info "Nginx-Setup für Domain: $DOMAIN"
echo ""

# Root-Rechte prüfen
if [ "$EUID" -ne 0 ]; then 
    print_error "Dieses Script muss mit sudo ausgeführt werden!"
    exit 1
fi

# Nginx und Certbot installieren
print_info "Installiere Nginx und Certbot..."
apt update
apt install -y certbot python3-certbot-nginx

# Verzeichnisse erstellen
print_info "Erstelle Web-Verzeichnisse..."
mkdir -p /var/www/grav
mkdir -p /var/www/devsandbox-warning

# Temporäre Index-Dateien erstellen
echo "<h1>Grav CMS - Coming Soon</h1>" > /var/www/grav/index.html
echo "<h1>DevSandbox - Warning</h1><p>This is a development environment.</p>" > /var/www/devsandbox-warning/index.html

# Korrekte Berechtigungen setzen
print_info "Setze Berechtigungen für Web-Verzeichnisse..."
chown -R www-data:www-data /var/www/grav
chown -R www-data:www-data /var/www/devsandbox-warning

# SSL-Zertifikate mit Certbot holen (mit default nginx config)
print_info "Hole SSL-Zertifikate mit Let's Encrypt..."

# Nginx muss laufen für Certbot
systemctl start nginx

# Zertifikate holen - das erstellt auch die SSL-Grunddateien
print_info "SSL für devsandbox.$DOMAIN..."
certbot --nginx \
    -d devsandbox.$DOMAIN \
    --email $EMAIL \
    --agree-tos \
    --no-eff-email \
    --non-interactive \
    --redirect || {
        print_warning "SSL-Zertifikat für devsandbox.$DOMAIN konnte nicht erstellt werden"
    }

print_info "SSL für $DOMAIN und www.$DOMAIN..."
certbot --nginx \
    -d $DOMAIN \
    -d www.$DOMAIN \
    --email $EMAIL \
    --agree-tos \
    --no-eff-email \
    --non-interactive \
    --redirect || {
        print_warning "SSL-Zertifikat für $DOMAIN konnte nicht erstellt werden"
    }

# Jetzt erst Default-Site entfernen
print_info "Entferne Default-Nginx-Site..."
rm -f /etc/nginx/sites-available/default
rm -f /etc/nginx/sites-enabled/default

# Script-Verzeichnis ermitteln
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
NGINX_FILES_DIR="${SCRIPT_DIR}/../nginx-files"

# Nginx-Konfigurationen kopieren und Domain einsetzen
print_info "Erstelle eigene Nginx-Konfigurationen..."

# Template-Dateien prüfen
if [ ! -d "$NGINX_FILES_DIR" ]; then
    print_error "nginx-files Verzeichnis nicht gefunden!"
    exit 1
fi

# Nginx-Configs aus Templates erstellen und Domain einsetzen
for template in "$NGINX_FILES_DIR"/*; do
    filename=$(basename "$template")
    print_info "Verarbeite $filename..."
    
    # Domain-Placeholder ersetzen und nach sites-available kopieren
    sed "s/DOMAIN_PLACEHOLDER/$DOMAIN/g" "$template" > "/etc/nginx/sites-available/$filename"
done

# Symlinks erstellen
print_info "Aktiviere Nginx-Sites..."
ln -sf /etc/nginx/sites-available/000-default-sanitizer /etc/nginx/sites-enabled/
ln -sf /etc/nginx/sites-available/devsandbox.dom /etc/nginx/sites-enabled/
ln -sf /etc/nginx/sites-available/www.dom /etc/nginx/sites-enabled/

# Nginx-Konfiguration testen
print_info "Teste Nginx-Konfiguration..."
nginx -t || {
    print_error "Nginx-Konfiguration fehlerhaft!"
    exit 1
}

# Nginx final neustarten
print_info "Finaler Nginx-Neustart..."
systemctl reload nginx

print_info "Nginx-Setup abgeschlossen!"
echo ""
echo "Status:"
echo "- Nginx läuft auf Port 80 und 443"
echo "- SSL-Zertifikate installiert für:"
echo "  - $DOMAIN"
echo "  - www.$DOMAIN"
echo "  - devsandbox.$DOMAIN"
echo "- Default-Sanitizer aktiv (blockiert unerwünschte Zugriffe)"
echo ""
print_warning "Hinweis: PHP/Python-Services sind noch nicht konfiguriert."
print_warning "Proxy-Weiterleitungen zeigen '502 Bad Gateway' bis die Services laufen."