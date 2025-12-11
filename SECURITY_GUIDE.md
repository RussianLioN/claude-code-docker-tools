# SECURITY_GUIDE.md

> **🔒 Comprehensive Security Guide**
> *Zero Trust security model, best practices, and threat mitigation*

**📍 Navigation**: [← Back to CLAUDE.md](./CLAUDE.md)

## 🛡️ Security Overview

This document outlines the comprehensive security model for the Dual AI Assistant Environment, implementing a Zero Trust architecture with defense-in-depth principles.

## 🎯 Security Architecture

### Core Principles

1. **Zero Trust**: Never trust, always verify
2. **Principle of Least Privilege**: Minimum necessary permissions
3. **Defense in Depth**: Multiple security layers
4. **Secure by Default**: Secure configuration out of the box

### Security Layers

```
┌─────────────────────────────────────────────────────────┐
│                 User Access Layer                        │
│  ├─ SSH Key Authentication                              │
│  ├─ Multi-factor Authentication (MFA)                   │
│  └─ Role-Based Access Control (RBAC)                   │
├─────────────────────────────────────────────────────────┤
│                 Network Security Layer                   │
│  ├─ SSH Agent Forwarding                               │
│  ├─ Container Network Isolation                        │
│  └─ Encrypted Communication                            │
├─────────────────────────────────────────────────────────┤
│                 Container Security Layer                 │
│  ├─ Read-only File Systems                             │
│  ├─ Resource Limits                                    │
│  ├─ Seccomp Profiles                                   │
│  └─ AppArmor/SELinux                                   │
├─────────────────────────────────────────────────────────┤
│                 Data Security Layer                      │
│  ├─ Encrypted Secrets Management                        │
│  ├─ Data-in-Transit Encryption                          │
│  ├─ Data-at-Rest Encryption                            │
│  └─ Secure Data Deletion                               │
├─────────────────────────────────────────────────────────┤
│                 Monitoring & Audit Layer                 │
│  ├─ Audit Logging                                       │
│  ├─ Intrusion Detection                                 │
│  ├─ Security Monitoring                                │
│  └─ Incident Response                                  │
└─────────────────────────────────────────────────────────┘
```

## 🔐 Authentication & Authorization

### SSH Key Management

**Requirements**:
- Ed25519 keys minimum (2048-bit RSA fallback)
- Passphrase-protected keys
- Regular key rotation (90 days)

**Setup**:
```bash
# Generate new key
ssh-keygen -t ed25519 -C "your.email@example.com"

# Add to SSH agent
ssh-add --apple-use-keychain ~/.ssh/id_ed25519

# Verify
ssh-add -l
```

**SSH Configuration**:
```bash
# ~/.ssh/config
Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519
  IdentitiesOnly yes
  PreferredAuthentications publickey
```

### API Key Security

**Claude API Key**:
```bash
# Secure storage (never in repository)
export CLAUDE_API_KEY="sk-ant-api03-..."
echo "export CLAUDE_API_KEY=\"sk-ant-api03-...\"" >> ~/.docker-ai-config/env
chmod 600 ~/.docker-ai-config/env
```

**Best Practices**:
- Use environment variables only
- Never hardcode in scripts
- Rotate keys regularly
- Use key management service for production

## 🔒 Container Security

### Container Hardening

**Dockerfile Security**:
```dockerfile
# Use specific version tags
FROM node:22-alpine@sha256:specific-hash

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S aiuser -u 1001

# Set minimal permissions
USER aiuser
WORKDIR /app

# Read-only where possible
COPY --chown=aiuser:nodejs . .
```

**Runtime Security**:
```bash
docker run --rm \
  --read-only \
  --tmpfs /tmp:noexec,nosuid,size=100m \
  --security-opt=no-new-privileges \
  --cap-drop ALL \
  --cap-add CHOWN \
  --cap-add SETGID \
  --cap-add SETUID \
  --memory=1g \
  --cpus=0.5 \
  claude-code-tools
```

### Security Scanning

**Image Vulnerability Scanning**:
```bash
# Trivy scan
trivy image claude-code-tools:latest

# Docker Scout (if available)
docker scout cves claude-code-tools:latest

# Grype (alternative)
grype claude-code-tools:latest
```

**CI/CD Integration**:
```yaml
# .github/workflows/security.yml
name: Security Scan
on: [push, pull_request]

jobs:
  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: 'claude-code-tools:latest'
          format: 'sarif'
          output: 'trivy-results.sarif'
```

## 🛡️ Network Security

### SSH Forwarding Security

**Current Implementation**:
```bash
# Secure agent forwarding
docker run -e SSH_AUTH_SOCK=/run/host-services/ssh-auth.sock \
           -v /run/host-services/ssh-auth.sock:/run/host-services/ssh-auth.sock \
           claude-code-tools
```

**Security Considerations**:
- Unix socket permissions (600)
- Limited to specific containers
- Agent lifetime management
- Forwarding audit logging

### Network Isolation

**Docker Network Configuration**:
```bash
# Create dedicated network
docker network create --driver bridge ai-network

# Run with network isolation
docker run --network ai-network \
           --network-alias ai-service \
           claude-code-tools
```

**Port Security**:
```bash
# Use dynamic port allocation
allocate_port() {
  local port
  for port in {9000..9999}; do
    if ! lsof -i ":$port" >/dev/null; then
      echo $port
      return 0
    fi
  done
  return 1
}
```

## 🔐 Data Protection

### Secrets Management

**Environment Variables**:
```bash
# Use .env file for local development
cat > .env << EOF
CLAUDE_API_KEY=sk-ant-api03-...
GEMINI_PROJECT_ID=your-project
EOF

# Load securely
set -a
source .env
set +a
```

**Production Secrets**:
```bash
# HashiCorp Vault integration
vault kv get secret/claude/api-key

# AWS Secrets Manager
aws secretsmanager get-secret-value --secret-id claude-api-key

# Kubernetes Secrets
kubectl create secret generic claude-api \
  --from-literal=api-key="sk-ant-api03-..."
```

### Data Encryption

**In-Transit**:
- SSH agent forwarding encrypted
- API calls over HTTPS/TLS
- Container communication encrypted

**At-Rest**:
```bash
# Encrypted configuration
gpg --symmetric --cipher-algo AES256 ~/.docker-ai-config/env

# Decrypt on demand
gpg --decrypt ~/.docker-ai-config/env.gpg > ~/.docker-ai-config/env
```

### Data Sanitization

**SSH Config Sanitization**:
```bash
# Remove macOS-specific options
grep -vE "UseKeychain|AddKeysToAgent|IdentityFile" ~/.ssh/config > clean_config
```

**Sensitive Data Exclusion**:
```bash
# .gitignore for security
.env
*.key
*.pem
*.gpg
.ai-state/
.docker-ai-config/*.json
.docker-ai-config/env
```

## 🔍 Monitoring & Detection

### Security Monitoring

**Container Monitoring**:
```bash
# Falco for runtime security
falco -c /etc/falco/falco_rules.yaml

# Audit container access
docker events --filter type=container
```

**Log Monitoring**:
```bash
# Security logs
tail -f /var/log/auth.log | grep sshd
tail -f ~/.docker-ai-config/logs/security.log

# Container logs
docker logs --tail 100 -f ai-container
```

### Intrusion Detection

**Fail2Ban Configuration**:
```ini
# /etc/fail2ban/jail.local
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
```

**Anomaly Detection**:
```python
# Example: Detect unusual SSH activity
import subprocess
import re
from datetime import datetime, timedelta

def detect_ssh_anomalies():
    # Parse auth logs for SSH failures
    result = subprocess.run(['lastb'], capture_output=True, text=True)

    # Count failures per IP
    ip_counts = {}
    for line in result.stdout.split('\n'):
        if 'ssh' in line:
            ip = re.findall(r'\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b', line)
            if ip:
                ip_counts[ip[0]] = ip_counts.get(ip[0], 0) + 1

    # Alert on high failure rates
    for ip, count in ip_counts.items():
        if count > 10:
            print(f"ALERT: High SSH failures from {ip}: {count}")
```

## 🚨 Incident Response

### Security Incident Procedures

**Immediate Response**:
1. **Isolation**: Stop affected containers
2. **Preservation**: Capture logs and evidence
3. **Assessment**: Determine scope and impact
4. **Communication**: Notify stakeholders

**Isolation Commands**:
```bash
# Stop all AI containers
docker stop $(docker ps -q --filter "label=ai.instance")

# Disconnect network
docker network disconnect ai-network $(docker ps -q)

# Revoke SSH agent
ssh-add -D
```

**Evidence Collection**:
```bash
# Create evidence directory
mkdir -p incident-$(date +%Y%m%d-%H%M%S)
cd incident-$(date +%Y%m%d-%H%M%S)

# Collect system information
uname -a > system-info.txt
docker info > docker-info.txt
docker ps -a > container-list.txt

# Collect logs
docker logs $(docker ps -aq) > all-container-logs.txt
journalctl -u docker > docker-service.log
```

### Recovery Procedures

**Service Restoration**:
```bash
# Verify system integrity
docker system prune -f
docker volume prune -f

# Restart with security monitoring
docker run --rm \
  --security-opt=no-new-privileges:true \
  --log-opt max-size=10m \
  --log-opt max-file=3 \
  claude-code-tools

# Validate security
docker run --rm \
  aquasec/trivy:latest \
  image --exit-code 1 \
  --severity HIGH,CRITICAL \
  claude-code-tools:latest
```

## 📋 Security Checklist

### Daily Security Checks

- [ ] Review running containers: `docker ps`
- [ ] Check for failed SSH attempts: `lastb`
- [ ] Verify no sensitive data in git: `git log -p | grep -i "key\|pass\|token"`
- [ ] Monitor resource usage: `docker stats`

### Weekly Security Reviews

- [ ] Update container images
- [ ] Rotate API keys if needed
- [ ] Review access logs
- [ ] Security scan with Trivy

### Monthly Security Audits

- [ ] Complete vulnerability assessment
- [ ] Review user access permissions
- [ ] Update security documentation
- [ ] Test incident response procedures

### Quarterly Security Updates

- [ ] Security training review
- [ ] Policy updates
- [ ] Tool upgrades
- [ ] Penetration testing (if applicable)

---

## 🏷️ Security Tags

```
Type: SECURITY_GUIDE
Compliance: Zero_Trust
Standards: NIST_CSF
Version: 2.0
Last_Audit: 2025-12-11
Next_Review: 2026-03-11
Classification: Internal_Use_Only
```