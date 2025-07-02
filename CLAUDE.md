# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains infrastructure-as-code for reproducible Hetzner Cloud server deployments using cloud-init.

## Common Commands

### Server Deployment
```bash
# Deploy a new server
./deploy.sh <server-name> [server-type] [location]

# List existing servers
hcloud server list

# Delete a server
hcloud server delete <server-name>
```

### Development
```bash
# Make deploy script executable
chmod +x deploy.sh

# Validate cloud-config syntax
cloud-init schema --config-file cloud-config.yaml
```

## Project Structure

```
hetzner/
├── cloud-config.yaml    # Cloud-init configuration for server setup
├── deploy.sh           # Deployment script using hcloud CLI
├── README.md          # User documentation
└── CLAUDE.md         # This file
```

## Key Architecture Decisions

1. **Cloud-init for configuration**: Ensures reproducible server setups
2. **Security-first approach**: Non-standard SSH port, key-only auth, firewall
3. **Simple bash scripts**: Easy to understand and modify
4. **No external dependencies**: Only requires hcloud CLI

## Important Notes

- SSH runs on port 2222 (not 22)
- Default user is `iosko` with sudo access
- Servers are hardened with UFW firewall and fail2ban
- Password authentication is disabled

## Future Improvements

When the user is ready:
- Add Terraform for more complex infrastructure
- Implement Ansible for application deployment
- Add backup and monitoring scripts
- Create different server profiles (web, database, etc.)