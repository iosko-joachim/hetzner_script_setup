#!/bin/bash

# HINWEIS: Dieses Script wird nicht verwendet, da wir via SSH-Agent-Forwarding deployen!
# Es bleibt hier als Referenz, falls später ein lokaler GitHub-Key auf dem Server benötigt wird.
#
# Setup GitHub SSH Key
# Dieses Script erstellt einen SSH-Key für GitHub und gibt den Public Key aus
# Der Key muss manuell in GitHub unter Settings > SSH Keys hinzugefügt werden

set -euo pipefail

# Farben für Output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== GitHub SSH Key Setup ===${NC}"
echo ""

# SSH-Verzeichnis erstellen falls nicht vorhanden
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Prüfen ob Key bereits existiert
if [ -f ~/.ssh/id_ed25519 ]; then
    echo -e "${YELLOW}Warnung: SSH-Key ~/.ssh/id_ed25519 existiert bereits!${NC}"
    echo "Möchten Sie ihn überschreiben? Dies löscht den existierenden Key!"
    read -p "Fortfahren? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Abgebrochen."
        exit 1
    fi
    echo ""
fi

# SSH-Key generieren
# -t ed25519: Moderner, sicherer Key-Typ
# -C: Kommentar zur Identifikation
# -f: Ausgabedatei (Standardname verwenden!)
echo "Erstelle neuen SSH-Key..."
ssh-keygen -t ed25519 -C "github@jr-gmbh-2nd-svr" -f ~/.ssh/id_ed25519 -N ""

# Berechtigungen setzen
chmod 600 ~/.ssh/id_ed25519
chmod 644 ~/.ssh/id_ed25519.pub

echo ""
echo -e "${GREEN}SSH-Key wurde erfolgreich erstellt!${NC}"
echo ""

# SSH-Agent konfigurieren
echo "Füge Key zum SSH-Agent hinzu..."
eval "$(ssh-agent -s)" > /dev/null
ssh-add ~/.ssh/id_ed25519

# Public Key ausgeben
echo -e "${GREEN}=== Ihr öffentlicher SSH-Key ===${NC}"
echo "Kopieren Sie den folgenden Key und fügen Sie ihn in GitHub ein:"
echo "(Settings → SSH and GPG keys → New SSH key)"
echo ""
echo "------- KEY START -------"
cat ~/.ssh/id_ed25519.pub
echo "------- KEY END ---------"
echo ""

# SSH-Config für GitHub
if ! grep -q "Host github.com" ~/.ssh/config 2>/dev/null; then
    echo "Erstelle SSH-Config für GitHub..."
    cat >> ~/.ssh/config << 'EOF'

Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519
    AddKeysToAgent yes
EOF
    chmod 600 ~/.ssh/config
    echo "SSH-Config wurde aktualisiert."
fi

echo ""
echo -e "${GREEN}Nächste Schritte:${NC}"
echo "1. Kopieren Sie den Public Key oben"
echo "2. Gehen Sie zu https://github.com/settings/keys"
echo "3. Klicken Sie auf 'New SSH key'"
echo "4. Geben Sie einen Namen ein (z.B. 'Hetzner Server')"
echo "5. Fügen Sie den Key ein und speichern"
echo ""
echo "Test der Verbindung mit: ssh -T git@github.com"