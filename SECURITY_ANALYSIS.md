# Sicherheitsanalyse der Remote-Tools

## 🔒 Übersicht der Sicherheitsrisiken

### Kritikalität-Skala
- 🟢 **Niedrig**: Minimales Risiko bei korrekter Konfiguration
- 🟡 **Mittel**: Erfordert Aufmerksamkeit und Best Practices
- 🔴 **Hoch**: Erhebliches Risiko, besondere Vorsicht erforderlich

## Tool-spezifische Sicherheitsanalyse

### cloud-init 🟡
**Risiken:**
- Secrets in cloud-config.yaml (Passwort-Hashes, API-Keys)
- User-data ist auf dem Server unter `/var/lib/cloud/instance/user-data.txt` lesbar
- Metadata-Service könnte exponiert sein

**Empfehlungen:**
```yaml
# NICHT machen:
users:
  - passwd: "klartext123"  # Niemals!
  
# Stattdessen:
users:
  - lock_passwd: true  # Nur SSH-Keys
```

**Best Practices:**
- Keine Secrets in cloud-config
- Dateien nach Ausführung löschen lassen
- Metadata-Service firewallen

### hcloud CLI 🟡
**Risiken:**
- API-Token mit voller Kontrolle
- Token in ~/.config/hcloud/cli.toml gespeichert
- Keine MFA-Unterstützung

**Sicherheitsmaßnahmen:**
```bash
# Token-Berechtigungen einschränken
chmod 600 ~/.config/hcloud/cli.toml

# Separates Token pro Umgebung
hcloud context create production --token=$PROD_TOKEN
hcloud context create staging --token=$STAGE_TOKEN
```

### SSH 🟢
**Risiken:**
- Key-Management
- Agent-Forwarding Angriffe
- Known-hosts Poisoning

**Härtung:**
```bash
# SSH-Config härten
Host *.production
    ForwardAgent no
    StrictHostKeyChecking yes
    HashKnownHosts yes
    
# SSH-Keys mit Passphrase
ssh-keygen -t ed25519 -a 100 -C "production-key"
```

### Ansible 🟡
**Risiken:**
- Vault-Passwörter im Klartext
- Privilege Escalation
- Man-in-the-Middle bei Host-Key-Checking

**Sichere Konfiguration:**
```ini
# ansible.cfg
[defaults]
host_key_checking = True
vault_password_file = ~/.ansible-vault-pass  # Chmod 600!
no_log = True  # Für sensitive Tasks

[ssh_connection]
pipelining = True
control_path = /tmp/ansible-%%h-%%p-%%r
```

**Ansible Vault für Secrets:**
```bash
# Secrets verschlüsseln
ansible-vault encrypt_string 'geheim123' --name 'db_password'

# In Playbook verwenden
- name: Set database password
  mysql_user:
    password: "{{ db_password }}"
  no_log: true
```

### Terraform 🔴
**Risiken:**
- State-File enthält ALLE Secrets im Klartext!
- Backend-Sicherheit kritisch
- Provider-Credentials

**Sicherheitsmaßnahmen:**
```hcl
# Backend verschlüsseln
terraform {
  backend "s3" {
    encrypt = true
    bucket  = "terraform-state"
    key     = "prod/terraform.tfstate"
  }
}

# Sensitive Variablen
variable "db_password" {
  type      = string
  sensitive = true
}

# Outputs nicht loggen
output "password" {
  value     = random_password.db.result
  sensitive = true
}
```

### Docker 🟡
**Risiken:**
- Container-Escape
- Image-Vulnerabilities
- Docker-Socket-Zugriff = Root

**Härtung:**
```bash
# Rootless Docker
curl -fsSL https://get.docker.com/rootless | sh

# Security Scanning
docker scan myimage:latest

# Read-only Container
docker run --read-only --tmpfs /tmp myapp
```

### GitHub Actions 🟡
**Risiken:**
- Secrets in Logs
- Supply-Chain-Attacks
- Überprivilegierte Workflows

**Best Practices:**
```yaml
# Minimale Berechtigungen
permissions:
  contents: read
  
# Secrets maskieren
- name: Deploy
  run: |
    echo "::add-mask::${{ secrets.API_KEY }}"
    deploy.sh
    
# Vertrauenswürdige Actions
- uses: actions/checkout@v4  # Immer Version pinnen!
```

## 🛡️ Allgemeine Sicherheitsmaßnahmen

### 1. Secrets Management

**NIEMALS:**
- Secrets in Git
- Secrets in Logs
- Secrets in cloud-config

**IMMER:**
```bash
# .gitignore
*.key
*.pem
.env
**/secrets/*
terraform.tfstate*

# Pre-commit Hook
pip install pre-commit
pre-commit install
```

### 2. Netzwerk-Sicherheit

```yaml
# Hetzner Cloud Firewall (vor UFW!)
resource "hcloud_firewall" "main" {
  name = "main"
  
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "2222"
    source_ips = ["YOUR.OFFICE.IP.0/24"]  # Nur von bekannten IPs!
  }
}
```

### 3. Audit & Monitoring

```bash
# Alle Remote-Zugriffe loggen
echo 'PROMPT_COMMAND="history -a; logger -t bash -p local1.info \"$USER: $PWD$ $(history 1)\""' >> /etc/bash.bashrc

# Fail2ban für alle Services
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3
```

### 4. Zero-Trust Ansatz

```nginx
# Zusätzliche Auth für Admin-Tools
location /admin {
    satisfy all;
    allow YOUR.IP.0.0/32;
    deny all;
    
    auth_basic "Admin Access";
    auth_basic_user_file /etc/nginx/.htpasswd;
}
```

## 🚨 Kritische Fehler vermeiden

### 1. Default Credentials
```bash
# FALSCH
mysql -u root  # Ohne Passwort!

# RICHTIG
mysql -u admin -p$MYSQL_ADMIN_PASSWORD
```

### 2. Öffentliche Services
```yaml
# FALSCH
ports:
  - "6379:6379"  # Redis für alle!
  
# RICHTIG  
ports:
  - "127.0.0.1:6379:6379"  # Nur lokal
```

### 3. Überprivilegierte Container
```yaml
# FALSCH
privileged: true
user: root

# RICHTIG
user: 1000:1000
read_only: true
cap_drop:
  - ALL
```

## 📋 Security Checkliste

### Vor dem Deployment
- [ ] Keine Secrets in Code/Config
- [ ] Alle Ports dokumentiert
- [ ] Firewall-Regeln definiert
- [ ] SSH-Keys mit Passphrase
- [ ] Backup-Strategie definiert

### Nach dem Deployment
- [ ] Unnötige Services deaktiviert
- [ ] Updates installiert
- [ ] Logs funktionieren
- [ ] Monitoring aktiv
- [ ] Firewall aktiv
- [ ] Fail2ban läuft

### Regelmäßig
- [ ] Security Updates (wöchentlich)
- [ ] Log-Review (täglich)
- [ ] Backup-Test (monatlich)
- [ ] Key-Rotation (jährlich)
- [ ] Penetration Test (jährlich)

## 🔐 Tool-Empfehlungen nach Sicherheit

### Höchste Sicherheit
1. **Hashicorp Vault** für Secrets
2. **Teleport** für SSH-Access
3. **Falco** für Runtime Security
4. **CIS Benchmarks** für Hardening

### Gute Balance
1. **Ansible + Vault**
2. **cloud-init** (ohne Secrets)
3. **WireGuard** für Admin-Zugang
4. **Prometheus + Alertmanager**

### Pragmatisch
1. **SSH + Keys**
2. **UFW + Fail2ban**
3. **Docker + Scanning**
4. **Einfache Backups**

## 📚 Weiterführende Ressourcen

- [CIS Benchmarks](https://www.cisecurity.org/cis-benchmarks/)
- [OWASP DevSecOps](https://owasp.org/www-project-devsecops-guideline/)
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)
- [BSI IT-Grundschutz](https://www.bsi.bund.de/DE/Themen/Unternehmen-und-Organisationen/Standards-und-Zertifizierung/IT-Grundschutz/it-grundschutz_node.html)