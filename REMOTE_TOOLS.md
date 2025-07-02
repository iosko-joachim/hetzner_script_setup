# Remote Tools für Hetzner Server Management

Diese Übersicht zeigt alle Tools, die für das Remote-Management von Hetzner-Servern verwendet werden können.

## 🔧 Aktuell im Einsatz

### cloud-init
- **Typ**: Initiale Konfiguration
- **Läuft auf**: Server (beim ersten Boot)
- **Konfiguration**: `cloud-config.yaml`
- **Funktionen**:
  - Benutzer anlegen
  - Pakete installieren
  - Firewall konfigurieren
  - SSH-Setup
  - Beliebige Befehle ausführen

### hcloud CLI
- **Typ**: Infrastructure Management
- **Läuft auf**: Lokaler Rechner
- **Installation**: `brew install hcloud` (macOS) oder Binary Download
- **Funktionen**:
  - Server erstellen/löschen
  - Netzwerke verwalten
  - Snapshots/Backups
  - Firewall-Regeln

### SSH
- **Typ**: Remote Access
- **Port**: 2222 (konfiguriert)
- **Authentifizierung**: SSH-Keys only
- **Verwendung**: `ssh -p 2222 iosko@<server-ip>`

## 📦 Configuration Management Tools

### Ansible ⭐ Empfohlen
```bash
# Installation
pip install ansible

# Beispiel-Nutzung
ansible-playbook -i inventory.yml playbook.yml
```
**Vorteile**:
- Kein Agent erforderlich
- YAML-basiert, leicht zu lernen
- Große Community
- Idempotent

**Nachteile**:
- Kann bei vielen Servern langsam werden
- Python-Abhängigkeit

### Salt
```bash
# Masterless Mode
salt-call --local state.apply
```
**Vorteile**:
- Sehr schnell
- Masterless-Mode möglich
- Event-driven

**Nachteile**:
- Steilere Lernkurve
- Weniger verbreitet als Ansible

### Terraform
```hcl
# Beispiel für Hetzner
resource "hcloud_server" "web" {
  name        = "web-server"
  server_type = "cx22"
  image       = "ubuntu-24.04"
  user_data   = file("cloud-config.yaml")
}
```
**Vorteile**:
- Infrastructure as Code
- State Management
- Multi-Cloud

**Nachteile**:
- Nur für Infrastruktur, nicht Konfiguration
- Lizenzänderungen bei Terraform

## 🐳 Container & Orchestration

### Docker + Docker Compose
```yaml
# Remote Docker deployment
DOCKER_HOST=ssh://iosko@server:2222 docker-compose up -d
```

### Kubernetes (k3s für Single Node)
```bash
# k3s Installation via cloud-init
curl -sfL https://get.k3s.io | sh -
```

## 📊 Monitoring & Logging

### Prometheus + Node Exporter
```yaml
# cloud-init Integration
runcmd:
  - wget https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz
  - tar xvf node_exporter-*.tar.gz
  - cp node_exporter-*/node_exporter /usr/local/bin/
  - # Systemd service erstellen...
```

### Netdata (Einfachste Option)
```bash
# One-line Installation
bash <(curl -Ss https://my-netdata.io/kickstart.sh)
```

## 🔄 CI/CD & Deployment

### GitHub Actions
```yaml
name: Deploy to Hetzner
on:
  push:
    branches: [main]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Deploy via SSH
        uses: appleboy/ssh-action@master
        with:
          host: ${{ secrets.HOST }}
          username: iosko
          key: ${{ secrets.SSH_KEY }}
          port: 2222
          script: |
            cd /app
            git pull
            docker-compose up -d
```

### Webhook-basiertes Deployment
```nginx
# Nginx webhook endpoint
location /deploy {
    proxy_pass http://localhost:9000/hooks/deploy;
}
```

## 💾 Backup-Lösungen

### Hetzner Snapshots (Einfachste)
```bash
# Via hcloud CLI
hcloud server create-image --description "Weekly backup" my-server
```

### Restic (Empfohlen für Daten)
```bash
# Backup zu Hetzner Storage Box
restic -r sftp:u123456@u123456.your-storagebox.de:backup init
restic backup /data
```

### Borg Backup
```bash
# Deduplizierte, verschlüsselte Backups
borg init --encryption=repokey ssh://u123456@u123456.your-storagebox.de:23/./backup
borg create ssh://u123456@u123456.your-storagebox.de:23/./backup::{now} /data
```

## 🚀 Deployment-Workflows

### 1. Minimal (Aktuell)
```
hcloud + cloud-init → Server läuft
```

### 2. Mit Configuration Management
```
hcloud + cloud-init → Basis-Setup
    ↓
Ansible → Anwendungs-Setup
```

### 3. GitOps Workflow
```
Git Push → GitHub Actions → SSH Deploy → Docker Update
```

### 4. Vollautomatisiert
```
Git Push → CI/CD → Terraform → cloud-init → Ansible → Monitoring
```

## 🎯 Entscheidungshilfe

### Wann welches Tool?

**Nur cloud-init**: 
- Einfache, statische Server
- Keine häufigen Änderungen

**cloud-init + Ansible**:
- Komplexere Konfigurationen
- Regelmäßige Updates
- Multiple Server

**Terraform + Ansible**:
- Multi-Server-Umgebungen
- Infrastructure as Code gewünscht
- Team-Zusammenarbeit

**Kubernetes**:
- Microservices
- Hohe Verfügbarkeit
- Container-Workloads

## 🔐 Sicherheitsaspekte

### SSH-Zugang
- Immer Key-basiert
- Nicht-Standard-Ports
- Fail2ban aktiviert
- SSH-Agent-Forwarding nur wenn nötig

### Secrets Management
- Niemals in Git committen
- Umgebungsvariablen nutzen
- Secrets Manager verwenden (Vault, SOPS)
- Hetzner Cloud Secrets (kommend)

### Netzwerk
- Private Networks für Inter-Server-Kommunikation
- Cloud Firewalls vor UFW
- Keine öffentlichen Datenbanken

## 📚 Weiterführende Ressourcen

- [Hetzner Cloud Docs](https://docs.hetzner.cloud/)
- [Cloud-init Dokumentation](https://cloudinit.readthedocs.io/)
- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)
- [Terraform Hetzner Provider](https://registry.terraform.io/providers/hetznercloud/hcloud/latest/docs)