# Hetzner Server Setup

Reproduzierbare Server-Konfiguration für Hetzner Cloud mit cloud-init.

## Voraussetzungen

1. [Hetzner Cloud Account](https://www.hetzner.com/cloud)
2. [hcloud CLI](https://github.com/hetznercloud/cli) installiert
3. API-Token erstellt (Hetzner Cloud Console → Security → API Tokens)
4. SSH-Key generiert

## Setup

### 1. hcloud CLI konfigurieren

```bash
hcloud context create my-project
# API-Token eingeben wenn gefragt
```

### 2. SSH-Key zu Hetzner Cloud hinzufügen

```bash
hcloud ssh-key create --name "jr-gmbh@hetzner" --public-key-from-file ~/.ssh/id_ed25519.pub
```

### 3. Server erstellen

```bash
./deploy.sh <server-name> [server-type] [location]
```

Beispiele:
```bash
# Standard-Server (cx22 in Nürnberg)
./deploy.sh web-server

# Größerer Server in Helsinki
./deploy.sh database-server cx32 hel1
```

## Server-Typen

| Typ | vCPU | RAM | Disk | Preis/Monat |
|-----|------|-----|------|-------------|
| cx22 | 2 | 4 GB | 40 GB | ~4€ |
| cx32 | 4 | 8 GB | 80 GB | ~8€ |
| cx42 | 8 | 16 GB | 160 GB | ~16€ |

## Locations

- `nbg1` - Nürnberg
- `fsn1` - Falkenstein  
- `hel1` - Helsinki

## Nach der Installation

Der Server wird automatisch konfiguriert mit:
- Ubuntu 24.04 LTS
- Benutzer: `iosko` (sudo-Rechte)
- SSH-Port: `2222` (nicht 22!)
- Firewall (UFW) aktiviert
- Fail2ban für SSH-Schutz
- Nginx installiert

### SSH-Verbindung

```bash
ssh -p 2222 iosko@<server-ip>
```

Oder fügen Sie zu `~/.ssh/config` hinzu:

```
Host mein-server
    HostName <server-ip>
    Port 2222
    User iosko
    ForwardAgent yes
```

## Sicherheitshinweise

- SSH läuft auf Port 2222 (nicht Standard-Port 22)
- Nur Key-basierte Authentifizierung (keine Passwörter)
- Root-Login deaktiviert
- Fail2ban blockiert nach 3 fehlgeschlagenen Versuchen
- UFW Firewall erlaubt nur: SSH (2222), HTTP (80), HTTPS (443)

## Server löschen

```bash
hcloud server delete <server-name>
```

## Troubleshooting

### Server-Status prüfen
```bash
hcloud server list
hcloud server describe <server-name>
```

### Cloud-init Logs ansehen (nach SSH-Login)
```bash
sudo tail -f /var/log/cloud-init-output.log
sudo cloud-init status
```

### Firewall-Status
```bash
sudo ufw status verbose
```

### Fail2ban-Status
```bash
sudo fail2ban-client status
sudo fail2ban-client status sshd
```