#!/bin/bash

# Grav CMS Setup
# Usage: ./002-setup-grav.sh

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

print_info "Grav CMS Setup startet..."
echo ""

# Root-Rechte prüfen
if [ "$EUID" -ne 0 ]; then 
    print_error "Dieses Script muss mit sudo ausgeführt werden!"
    exit 1
fi

# PHP installieren
print_info "Installiere PHP und benötigte Module..."
apt update
apt install -y \
    php-cli \
    php-fpm \
    php-zip \
    php-mbstring \
    php-curl \
    php-dom \
    php-gd \
    php-xml

# PHP-FPM aktivieren und starten
print_info "Aktiviere PHP 8.3 FPM..."
systemctl enable php8.3-fpm
systemctl start php8.3-fpm

# Prüfen ob PHP-FPM läuft
if systemctl is-active --quiet php8.3-fpm; then
    print_info "PHP-FPM läuft erfolgreich"
else
    print_error "PHP-FPM konnte nicht gestartet werden!"
    exit 1
fi

# Script-Verzeichnis VOR dem cd ermitteln
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PAGES_DIR="${SCRIPT_DIR}/../grav-user-pages/pages"

# Grav herunterladen
print_info "Lade Grav CMS herunter..."
cd /tmp
curl -L -O https://getgrav.org/download/core/grav-admin/latest || {
    print_error "Grav Download fehlgeschlagen!"
    exit 1
}

# Grav entpacken
print_info "Entpacke Grav..."
unzip -q latest -d grav-temp || {
    print_error "Entpacken fehlgeschlagen!"
    exit 1
}

# Altes Verzeichnis löschen falls vorhanden
if [ -d "/var/www/grav" ]; then
    print_warning "Existierendes Grav-Verzeichnis wird überschrieben..."
    rm -rf /var/www/grav
fi

# Grav verschieben
print_info "Installiere Grav nach /var/www/grav..."
mv grav-temp/grav-admin /var/www/grav

# Custom Pages kopieren
if [ -d "$PAGES_DIR" ]; then
    print_info "Kopiere custom Pages..."
    
    # Alte Pages löschen
    rm -rf /var/www/grav/user/pages/*
    
    # Neue Pages kopieren
    cp -r "$PAGES_DIR"/* /var/www/grav/user/pages/
    
    print_info "Custom Pages erfolgreich installiert"
else
    print_warning "Keine custom Pages gefunden in $PAGES_DIR"
fi

# Config-Dateien kopieren
CONFIG_DIR="${SCRIPT_DIR}/../grav-config"
if [ -d "$CONFIG_DIR" ]; then
    print_info "Kopiere Konfigurationsdateien..."

    # site.yaml
    if [ -f "$CONFIG_DIR/site.yaml" ]; then
        cp "$CONFIG_DIR/site.yaml" /var/www/grav/user/config/site.yaml
        chown www-data:www-data /var/www/grav/user/config/site.yaml
        print_info "Site-Konfiguration installiert"
    fi

    # system.yaml
    if [ -f "$CONFIG_DIR/system.yaml" ]; then
        cp "$CONFIG_DIR/system.yaml" /var/www/grav/user/config/system.yaml
        chown www-data:www-data /var/www/grav/user/config/system.yaml
        print_info "System-Konfiguration installiert"
    fi

    # Plugin-Konfigurationen
    if [ -d "$CONFIG_DIR/plugins" ]; then
        mkdir -p /var/www/grav/user/config/plugins
        cp -r "$CONFIG_DIR/plugins"/* /var/www/grav/user/config/plugins/
        chown -R www-data:www-data /var/www/grav/user/config/plugins
        print_info "Plugin-Konfigurationen installiert"
    fi

    # Theme-Konfigurationen
    if [ -d "$CONFIG_DIR/themes" ]; then
        mkdir -p /var/www/grav/user/config/themes
        cp -r "$CONFIG_DIR/themes"/* /var/www/grav/user/config/themes/
        chown -R www-data:www-data /var/www/grav/user/config/themes
        print_info "Theme-Konfigurationen installiert"
    fi
else
    print_info "Keine Konfigurationsdateien gefunden, überspringe..."
fi

# Assets kopieren (Favicon etc.)
ASSETS_DIR="${SCRIPT_DIR}/../grav-assets"
if [ -d "$ASSETS_DIR" ]; then
    print_info "Kopiere Assets..."
    
    # Favicon ICO (für Root)
    if [ -f "$ASSETS_DIR/favicon.ico" ]; then
        cp "$ASSETS_DIR/favicon.ico" /var/www/grav/favicon.ico
        chown www-data:www-data /var/www/grav/favicon.ico
        print_info "Favicon.ico installiert"
    fi
    
    # Favicon PNG (für Theme)
    if [ -f "$ASSETS_DIR/favicon.png" ]; then
        # Aktives Theme aus Grav-Config ermitteln
        if [ -f "/var/www/grav/user/config/system.yaml" ]; then
            ACTIVE_THEME=$(grep -E "^\s*theme:" /var/www/grav/user/config/system.yaml | awk '{print $2}' | tr -d ' ')
            if [ -n "$ACTIVE_THEME" ]; then
                THEME_IMG_DIR="/var/www/grav/user/themes/$ACTIVE_THEME/images"
                if [ -d "$THEME_IMG_DIR" ]; then
                    cp "$ASSETS_DIR/favicon.png" "$THEME_IMG_DIR/favicon.png"
                    chown www-data:www-data "$THEME_IMG_DIR/favicon.png"
                    print_info "Theme-Favicon installiert für: $ACTIVE_THEME"
                else
                    print_warning "Theme-Bilder-Verzeichnis nicht gefunden: $THEME_IMG_DIR"
                fi
            else
                print_warning "Kein aktives Theme in Grav-Config gefunden"
            fi
        else
            print_warning "Grav-Config nicht gefunden, überspringe Theme-Favicon"
        fi
    fi
    
    # Weitere Assets können hier hinzugefügt werden
else
    print_info "Keine Assets gefunden, überspringe..."
fi

# Templates kopieren (überschreibt Theme-Templates)
TEMPLATES_DIR="${SCRIPT_DIR}/../grav-templates"
if [ -d "$TEMPLATES_DIR" ]; then
    print_info "Kopiere Custom Templates..."
    
    # Prüfe aktives Theme für Template-Pfad
    if [ -f "/var/www/grav/user/config/system.yaml" ]; then
        ACTIVE_THEME=$(grep -E "^\s*theme:" /var/www/grav/user/config/system.yaml | awk '{print $2}' | tr -d ' ')
        if [ -n "$ACTIVE_THEME" ]; then
            THEME_TEMPLATES="/var/www/grav/user/themes/$ACTIVE_THEME/templates"
            if [ -d "$THEME_TEMPLATES" ]; then
                # Kopiere alle Templates und behalte Verzeichnisstruktur
                cp -r "$TEMPLATES_DIR"/* "$THEME_TEMPLATES/"
                chown -R www-data:www-data "$THEME_TEMPLATES"
                print_info "Custom Templates installiert für Theme: $ACTIVE_THEME"
            else
                print_warning "Theme-Template-Verzeichnis nicht gefunden: $THEME_TEMPLATES"
            fi
        fi
    fi
else
    print_info "Keine Custom Templates gefunden, überspringe..."
fi

# Berechtigungen setzen
print_info "Setze Berechtigungen..."
chown -R www-data:www-data /var/www/grav
chmod -R 755 /var/www/grav

# Schreibrechte für bestimmte Verzeichnisse
chmod -R 775 /var/www/grav/cache
chmod -R 775 /var/www/grav/logs
chmod -R 775 /var/www/grav/images
chmod -R 775 /var/www/grav/assets
chmod -R 775 /var/www/grav/user/data
chmod -R 775 /var/www/grav/backup
chmod -R 775 /var/www/grav/tmp

# Aufräumen
print_info "Räume temporäre Dateien auf..."
cd /
rm -rf /tmp/grav-temp
rm -f /tmp/latest

# PHP-FPM Socket-Pfad prüfen
SOCKET_PATH="/var/run/php/php8.3-fpm.sock"
if [ -S "$SOCKET_PATH" ]; then
    print_info "PHP-FPM Socket gefunden: $SOCKET_PATH"
else
    # Fallback auf andere PHP-Version
    SOCKET_PATH=$(find /var/run/php/ -name "php*-fpm.sock" | head -n1)
    if [ -n "$SOCKET_PATH" ]; then
        print_warning "Nutze PHP-FPM Socket: $SOCKET_PATH"
        print_warning "Nginx-Config muss möglicherweise angepasst werden!"
    else
        print_error "Kein PHP-FPM Socket gefunden!"
    fi
fi

# Nginx neustarten für PHP
print_info "Starte Nginx neu..."
systemctl reload nginx

print_info "Grav CMS Setup abgeschlossen!"
echo ""
echo "Status:"
echo "- Grav CMS installiert in /var/www/grav"
echo "- PHP-FPM läuft"
echo "- Custom Pages installiert"
echo "- Berechtigungen gesetzt"
echo ""
echo "Grav Admin-Panel: https://ihre-domain.com/admin"
echo "Standard-Login beim ersten Aufruf erstellen!"