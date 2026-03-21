# Security Hardening Guide

## Overview

This document outlines the security features and hardening measures implemented in this PostgreSQL HA cluster deployment. **SECURITY IS CRITICAL** - follow this guide carefully for production deployments.

## 🔒 Security Features Enabled by Default

### 1. **PostgreSQL Authentication**

✅ **SCRAM-SHA-256** authentication (industry standard, replaces deprecated MD5)

- All connections use `scram-sha-256` hash algorithm
- Passwords never transmitted in cleartext
- Protection against rainbow table attacks

### 2. **Network Access Control**

✅ **Restricted pg_hba.conf** rules:

```
# ❌ REMOVED: host all all 0.0.0.0/0 md5 (DANGEROUS!)
# ✅ SECURE: Only cluster network allowed
- host all all <CLUSTER_NETWORK> scram-sha-256
```

**Default behavior**: Only nodes within `CLUSTER_NETWORK` (e.g., 10.0.0.0/24) can connect to PostgreSQL.

### 3. **SSL/TLS Encryption**

✅ **PostgreSQL SSL enabled by default** (`POSTGRESQL_SSL_ENABLED=true`)

- Encrypts all client-server communication
- Prevents password sniffing and man-in-the-middle attacks
- Self-signed certificates auto-generated if not provided

### 4. **Patroni REST API Authentication**

✅ **HTTP Basic Auth** enabled by default:

```yaml
PATRONI_RESTAPI_AUTH_ENABLED=true
PATRONI_RESTAPI_USERNAME=patroni_admin
PATRONI_RESTAPI_PASSWORD=<strong_password>
```

**Protected endpoints**: `/switchover`, `/failover`, `/restart`, `/reload`, `/reinitialize`

### 5. **etcd Authentication**

✅ **etcd auth enabled** (`ETCD_AUTH_ENABLED=true`)

- Root user password required
- Prevents unauthorized cluster state manipulation
- **CRITICAL**: etcd stores all cluster secrets and topology

### 6. **PgBouncer Security**

✅ **SCRAM-SHA-256** authentication:

```ini
auth_type = scram-sha-256
auth_query = SELECT usename, passwd FROM pg_shadow WHERE usename=$1
```

### 7. **Strong Password Requirements**

✅ **Mandatory password complexity**:

- Minimum 16 characters
- Mix of uppercase, lowercase, numbers, symbols
- Generated with `openssl rand -base64 32`

## 🚨 Critical CVE Status

### PostgreSQL 18.1 → 18.2+ Required

**CVE-2025-8714** (CVSS 8.8 HIGH):

- Affects: pg_dump arbitrary code execution
- Impact: Malicious dumps can execute code during restore
- **Action Required**: Upgrade to PostgreSQL 18.2+ immediately

**Other Recent CVEs Fixed:**

- CVE-2025-4207: Optimizer statistics exposure (18.5+)
- CVE-2025-1094: GB18030 encoding vulnerability (18.3+)
- CVE-2024-10979: Quoting API validation bypass (18.1+)
- CVE-2024-10978: PL/Perl environment variable injection (18.1+)

## 🛡️ Security Checklist

### Pre-Deployment

- [ ] **Generate strong passwords** for all accounts:

```bash
# PostgreSQL superuser
openssl rand -base64 32 > /tmp/pg_superuser_pass

# Replication user
openssl rand -base64 32 > /tmp/pg_replication_pass

# Admin user
openssl rand -base64 32 > /tmp/pg_admin_pass

# etcd root
openssl rand -base64 32 > /tmp/etcd_root_pass

# Patroni REST API
openssl rand -base64 32 > /tmp/patroni_api_pass

# Grafana admin
openssl rand -base64 24 > /tmp/grafana_admin_pass
```

- [ ] **Configure `.env` file** with generated passwords:

```bash
cp .env.example .env
nano .env
# Fill in all empty password fields
```

- [ ] **Verify SSL is enabled**:

```bash
grep POSTGRESQL_SSL_ENABLED .env
# Should be: POSTGRESQL_SSL_ENABLED=true
```

- [ ] **Verify authentication is enabled**:

```bash
grep -E "(ETCD_AUTH_ENABLED|PATRONI_RESTAPI_AUTH_ENABLED)" .env
# Both should be: true
```

- [ ] **Review network configuration**:

```bash
grep CLUSTER_NETWORK .env
# Ensure it matches your actual cluster subnet
```

### Post-Deployment

- [ ] **Test SSL connections**:

```bash
psql "postgresql://admin@<node-ip>:5432/postgres?sslmode=require"
```

- [ ] **Verify Patroni API auth**:

```bash
# Should fail without credentials
curl http://<node-ip>:8008/patroni

# Should succeed with credentials
curl -u patroni_admin:<password> http://<node-ip>:8008/patroni
```

- [ ] **Check firewall rules**:

```bash
ssh root@<node-ip> "ufw status"
# Verify only required ports are open
```

- [ ] **Audit user permissions**:

```bash
psql -U postgres -c "\du"
# Verify no unexpected superusers
```

- [ ] **Change Grafana password** on first login

- [ ] **Enable audit logging** (optional but recommended):

```sql
ALTER SYSTEM SET log_connections = 'on';
ALTER SYSTEM SET log_disconnections = 'on';
ALTER SYSTEM SET log_statement = 'ddl';
SELECT pg_reload_conf();
```

## 🔥 Common Security Mistakes to Avoid

### ❌ DON'T

1. **Use weak/default passwords**
   - ❌ `admin123`, `password`, `postgres`
   - ✅ Use `openssl rand -base64 32`

2. **Open PostgreSQL to the internet**
   - ❌ `host all all 0.0.0.0/0 md5`
   - ✅ Restrict to `CLUSTER_NETWORK` only

3. **Disable SSL in production**
   - ❌ `POSTGRESQL_SSL_ENABLED=false`
   - ✅ Always enable SSL: `POSTGRESQL_SSL_ENABLED=true`

4. **Leave Patroni API unprotected**
   - ❌ `PATRONI_RESTAPI_AUTH_ENABLED=false`
   - ✅ Enable auth to prevent unauthorized failovers

5. **Use MD5 authentication**
   - ❌ `PGBOUNCER_AUTH_TYPE=md5` (vulnerable to rainbow tables)
   - ✅ Use `scram-sha-256`

6. **Commit `.env` file to git**
   - ❌ Contains all cluster secrets!
   - ✅ Ensure `.env` is in `.gitignore`

7. **Run as root user**
   - ❌ PostgreSQL, etcd should have dedicated users
   - ✅ Already configured with `postgres`, `etcd` users

8. **Skip etcd authentication**
   - ❌ Anyone can read/write cluster state
   - ✅ `ETCD_AUTH_ENABLED=true` is mandatory

## 🔐 Advanced Security Hardening

### 1. SSL Certificate Management

**Production Setup** - Use proper CA-signed certificates:

```bash
# Generate CA certificate
openssl req -new -x509 -days 3650 -nodes \
  -out /etc/postgresql/ssl/root.crt \
  -keyout /etc/postgresql/ssl/root.key \
  -subj "/CN=PostgreSQL-HA-CA"

# Generate server certificate for each node
for node in node1 node2 node3; do
  openssl req -new -nodes \
    -out /etc/postgresql/ssl/${node}.csr \
    -keyout /etc/postgresql/ssl/${node}.key \
    -subj "/CN=${node}.cluster.local"
  
  openssl x509 -req -in /etc/postgresql/ssl/${node}.csr \
    -CA /etc/postgresql/ssl/root.crt \
    -CAkey /etc/postgresql/ssl/root.key \
    -CAcreateserial \
    -out /etc/postgresql/ssl/${node}.crt \
    -days 365
done

# Set permissions
chmod 600 /etc/postgresql/ssl/*.key
chown postgres:postgres /etc/postgresql/ssl/*
```

**Update `.env`:**

```bash
POSTGRESQL_SSL_CERT_FILE=/etc/postgresql/ssl/<node>.crt
POSTGRESQL_SSL_KEY_FILE=/etc/postgresql/ssl/<node>.key
POSTGRESQL_SSL_CA_FILE=/etc/postgresql/ssl/root.crt
```

### 2. etcd TLS Configuration

**Generate etcd certificates:**

```bash
# Create etcd SSL directory
mkdir -p /etc/etcd/ssl

# Generate CA for etcd
openssl req -new -x509 -days 3650 -nodes \
  -out /etc/etcd/ssl/ca.crt \
  -keyout /etc/etcd/ssl/ca.key \
  -subj "/CN=etcd-CA"

# Generate server cert for each node
for node in node1 node2 node3; do
  openssl req -new -nodes \
    -out /etc/etcd/ssl/${node}.csr \
    -keyout /etc/etcd/ssl/${node}.key \
    -subj "/CN=${node}"
  
  openssl x509 -req -in /etc/etcd/ssl/${node}.csr \
    -CA /etc/etcd/ssl/ca.crt \
    -CAkey /etc/etcd/ssl/ca.key \
    -CAcreateserial \
    -out /etc/etcd/ssl/${node}.crt \
    -days 365
done
```

**Update etcd.conf.j2:**

```yaml
ETCD_LISTEN_CLIENT_URLS="https://{{ ansible_host }}:2379"
ETCD_LISTEN_PEER_URLS="https://{{ ansible_host }}:2380"
ETCD_CERT_FILE="/etc/etcd/ssl/{{ etcd_name }}.crt"
ETCD_KEY_FILE="/etc/etcd/ssl/{{ etcd_name }}.key"
ETCD_TRUSTED_CA_FILE="/etc/etcd/ssl/ca.crt"
ETCD_PEER_CERT_FILE="/etc/etcd/ssl/{{ etcd_name }}.crt"
ETCD_PEER_KEY_FILE="/etc/etcd/ssl/{{ etcd_name }}.key"
ETCD_PEER_TRUSTED_CA_FILE="/etc/etcd/ssl/ca.crt"
```

### 3. Prometheus/Grafana HTTPS

**Nginx reverse proxy** with Let's Encrypt:

```nginx
server {
    listen 443 ssl http2;
    server_name monitoring.example.com;

    ssl_certificate /etc/letsencrypt/live/monitoring.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/monitoring.example.com/privkey.pem;

    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

### 4. Network Segmentation

**Firewall rules** (UFW example):

```bash
# PostgreSQL - cluster nodes only
ufw allow from $CLUSTER_NETWORK to any port 5432 proto tcp

# PgBouncer - application servers only
ufw allow from <app_subnet>/24 to any port 6432 proto tcp

# etcd - cluster nodes only
ufw allow from $CLUSTER_NETWORK to any port 2379,2380 proto tcp

# Patroni API - monitoring server only
ufw allow from <monitoring_ip> to any port 8008 proto tcp

# Monitoring exporters - monitoring server only
ufw allow from <monitoring_ip> to any port 9100,9187,9127 proto tcp

# Prometheus/Grafana - VPN or trusted IPs only
ufw allow from <vpn_subnet>/24 to any port 9090,3000 proto tcp

# Enable firewall
ufw enable
```

### 5. Audit Logging

**Enable pgAudit extension**:

```sql
CREATE EXTENSION pgaudit;

ALTER SYSTEM SET pgaudit.log = 'all';
ALTER SYSTEM SET pgaudit.log_catalog = 'off';
ALTER SYSTEM SET pgaudit.log_parameter = 'on';
ALTER SYSTEM SET pgaudit.log_relation = 'on';

SELECT pg_reload_conf();
```

**Monitor logs**:

```bash
tail -f /var/log/postgresql/postgresql-*.log | grep AUDIT
```

### 6. Intrusion Detection

**Install fail2ban**:

```bash
apt install fail2ban

# Create /etc/fail2ban/filter.d/postgresql.conf
[Definition]
failregex = FATAL:  password authentication failed for user ".*" <HOST>
ignoreregex =

# Create /etc/fail2ban/jail.d/postgresql.conf
[postgresql]
enabled = true
port = 5432,6432
filter = postgresql
logpath = /var/log/postgresql/postgresql-*.log
maxretry = 5
bantime = 3600
```

### 7. Secrets Management

**Use Ansible Vault** for `.env` encryption:

```bash
# Encrypt .env
ansible-vault encrypt .env

# Deploy with vault password
ansible-playbook playbooks/site.yml --ask-vault-pass

# Decrypt for editing
ansible-vault decrypt .env
nano .env
ansible-vault encrypt .env
```

**Or use HashiCorp Vault**:

```bash
# Store secrets in Vault
vault kv put secret/postgres/superuser password=$(openssl rand -base64 32)
vault kv put secret/postgres/replication password=$(openssl rand -base64 32)

# Retrieve in Ansible
vars:
  postgresql_superuser_password: "{{ lookup('hashi_vault', 'secret/postgres/superuser:password') }}"
```

## 📊 Security Monitoring

### Metrics to Monitor

1. **Failed login attempts**:

```sql
SELECT count(*) FROM pg_stat_activity 
WHERE state = 'idle in transaction failed';
```

1. **Superuser connections**:

```sql
SELECT usename, client_addr, backend_start 
FROM pg_stat_activity 
WHERE usesysid = 10;
```

1. **SSL connection ratio**:

```sql
SELECT 
  count(*) FILTER (WHERE ssl = true) AS ssl_connections,
  count(*) FILTER (WHERE ssl = false) AS non_ssl_connections
FROM pg_stat_ssl;
```

1. **Patroni failover events**:

```bash
journalctl -u patroni | grep -i "failover"
```

### Alerting Rules

Check `roles/prometheus/templates/alert_rules.yml.j2` for:

- `PostgreSQLDown`
- `PostgreSQLTooManyConnections`
- `PatroniNoLeader`
- `EtcdNoLeader`
- `HighReplicationLag`

## 🆘 Incident Response

### Suspected Breach

1. **Immediately change all passwords**:

```bash
psql -U postgres -c "ALTER USER postgres PASSWORD '<new_password>';"
psql -U postgres -c "ALTER USER replicator PASSWORD '<new_password>';"
psql -U postgres -c "ALTER USER admin PASSWORD '<new_password>';"
```

1. **Review connections**:

```sql
SELECT pid, usename, client_addr, backend_start, state 
FROM pg_stat_activity 
WHERE client_addr IS NOT NULL;
```

1. **Terminate suspicious connections**:

```sql
SELECT pg_terminate_backend(pid) 
FROM pg_stat_activity 
WHERE client_addr = '<suspicious_ip>';
```

1. **Review audit logs**:

```bash
grep -i "authentication failed" /var/log/postgresql/*.log
grep -i "FATAL" /var/log/postgresql/*.log
```

1. **Enable connection logging temporarily**:

```sql
ALTER SYSTEM SET log_connections = 'on';
ALTER SYSTEM SET log_disconnections = 'on';
SELECT pg_reload_conf();
```

## 📚 Compliance

### GDPR/HIPAA Requirements

- ✅ **Encryption at rest**: Enable with LUKS/dm-crypt
- ✅ **Encryption in transit**: SSL/TLS enabled
- ✅ **Access control**: SCRAM-SHA-256, network restrictions
- ✅ **Audit logging**: pgAudit extension
- ✅ **Data retention**: Configure in Patroni
- ✅ **Right to be forgotten**: Implement data deletion procedures

### PCI-DSS Requirements

- ✅ **Requirement 2.1**: Change default passwords (enforced)
- ✅ **Requirement 4**: Encrypt transmission (SSL/TLS)
- ✅ **Requirement 8**: Unique user IDs (no shared accounts)
- ✅ **Requirement 10**: Track and monitor access (audit logging)

## 🔄 Regular Security Tasks

### Daily

- [ ] Review failed login attempts
- [ ] Check for unusual connection patterns
- [ ] Monitor replication lag

### Weekly

- [ ] Review user permissions
- [ ] Check for CVE updates
- [ ] Rotate backup encryption keys

### Monthly

- [ ] Password rotation (optional, if policy requires)
- [ ] SSL certificate expiry check
- [ ] Security patch updates
- [ ] Audit log review

### Quarterly

- [ ] Full security audit
- [ ] Penetration testing
- [ ] Disaster recovery drill
- [ ] Update security documentation

## 📞 Support

For security issues:

- PostgreSQL Security: <security@postgresql.org>
- CVE Database: <https://www.postgresql.org/support/security/>
- Project Issues: <https://github.com/xdev-asia-labs/postgres-patroni-etcd-install/issues>

**NEVER** disclose security vulnerabilities publicly. Report privately first.
