# PostgreSQL HA Cluster - Ansible Automation

## Project Overview

This is an **Ansible-based infrastructure automation project** that deploys a production-ready PostgreSQL 18.1 High Availability cluster using:
- **Patroni 4.1.0** for HA management and automatic failover (30-45s failover time)
- **etcd 3.5.25** as distributed configuration store (DCS) for leader election
- **PgBouncer 1.25.0** for connection pooling (port 6432 - primary application interface)
- **PostgreSQL 18.1** streaming replication across 3 nodes

**Critical Architecture Principle**: Applications connect to PgBouncer (port 6432), NOT directly to PostgreSQL (port 5432). PgBouncer provides 13x connection multiplexing (3000 client → 225 backend connections).

## Configuration Architecture

### Environment-Driven Configuration Pattern

**ALL configuration is externalized to `.env` file** (70+ variables). Ansible variables in `inventory/group_vars/all.yml` use `lookup('env', 'VAR_NAME')` to read from environment:

```yaml
postgresql_version: "{{ lookup('env', 'POSTGRESQL_VERSION') | default('18', true) }}"
postgresql_superuser_password: "{{ lookup('env', 'POSTGRESQL_SUPERUSER_PASSWORD') }}"
```

**Critical Workflow**: Before ANY Ansible execution:
```bash
set -a && source .env && set +a
ansible-playbook playbooks/site.yml -i inventory/hosts.yml
```

Never hardcode values in templates or tasks - always reference variables from `inventory/group_vars/all.yml`.

### Inventory Structure

Three-node cluster defined in `inventory/hosts.yml`:
```yaml
postgres:
  hosts:
    pg-node1:
      ansible_host: $NODE1_IP
      patroni_name: node1
      etcd_name: etcd1
```

Each node runs ALL services: PostgreSQL, Patroni, etcd, PgBouncer. Use `groups['postgres']` for iterating all nodes.

## Playbook Execution Model

### Main Deployment (`playbooks/site.yml`)

Sequential role execution pattern:
1. **common**: System setup, time sync, hostname, firewall
2. **postgresql**: Install PostgreSQL 18.1 binaries
3. **etcd**: Bootstrap etcd cluster (all nodes in parallel)
4. **patroni**: Initialize Patroni cluster (first node waits, then others join)
5. **pgbouncer**: Configure connection pooler per node

**Critical**: Patroni starts on `groups['postgres'][0]` first, waits for cluster init (120s timeout), then starts remaining nodes to avoid split-brain.

### Operational Playbooks

- `switchover.yml`: Planned leader migration (requires `-e "target_node=node2"`)
- `rolling-update.yml`: Zero-downtime updates (pause cluster, update replicas, switchover, update old leader)
- `backup.yml`: pg_basebackup from current leader
- `add-replica.yml`: Add new node to existing cluster

Always use `patronictl -c /etc/patroni/patroni.yml <command>` for cluster operations, never direct `systemctl restart postgresql`.

## Component Integration Points

### Patroni ↔ etcd Communication

Patroni discovers etcd endpoints via Jinja2 loop in `roles/patroni/templates/patroni.yml.j2`:
```jinja
etcd3:
  hosts: {% for host in groups['postgres'] %}{{ hostvars[host]['ansible_host'] }}:{{ etcd_client_port }}{% if not loop.last %},{% endif %}{% endfor %}
```

Generates: `$NODE1_IP:2379,$NODE2_IP:2379,$NODE3_IP:2379`

### PgBouncer ↔ PostgreSQL Integration

PgBouncer connects to **localhost:5432** only (managed by Patroni on same node). Template `roles/pgbouncer/templates/pgbouncer.ini.j2` uses:
```ini
[databases]
* = host=127.0.0.1 port=5432
```

Patroni ensures PgBouncer always points to correct local PostgreSQL state (primary/replica).

### Callback Scripts

Patroni hooks in `roles/patroni/templates/patroni.yml.j2`:
```yaml
on_role_change: /etc/patroni/scripts/on_role_change.sh
on_start: /etc/patroni/scripts/on_start.sh
on_stop: /etc/patroni/scripts/on_stop.sh
```

Used for monitoring integration, alerts, or service reconfiguration on role changes.

## Critical Development Workflows

### Testing Configuration Changes

1. Modify variables in `.env`
2. Load environment: `set -a && source .env && set +a`
3. Dry run: `ansible-playbook playbooks/site.yml --check --diff`
4. Execute: `ansible-playbook playbooks/site.yml --tags "patroni"`
5. Verify: `ssh root@$NODE1_IP "patronictl -c /etc/patroni/patroni.yml list"`

### Adding New Role

1. Create role structure: `mkdir -p roles/newrole/{tasks,templates,handlers,defaults}`
2. Define variables in `inventory/group_vars/all.yml` with env lookups
3. Add corresponding vars to `.env.example`
4. Include role in `playbooks/site.yml` with appropriate tags
5. Add firewall rules in `roles/common/tasks/main.yml` if needed

### Template Development

Use Jinja2 with strict variable references. Common patterns:

**Multi-node iteration**:
```jinja
{% for host in groups['postgres'] %}
{{ hostvars[host]['ansible_host'] }}
{% endfor %}
```

**Conditional sections**:
```jinja
{% if patroni_restapi_auth_enabled | default(false) %}
authentication:
  username: {{ patroni_restapi_username }}
{% endif %}
```

**Always use variable defaults**: `{{ var_name | default('fallback', true) }}`

## Port Allocation & Service Discovery

| Service | Port | Access | Purpose |
|---------|------|--------|---------|
| **PgBouncer** | **6432** | **Application** | **Primary connection point** |
| PostgreSQL | 5432 | Internal | Admin/maintenance only |
| Patroni REST | 8008 | Internal | Health checks (`/health`, `/primary`, `/replica`) |
| etcd Client | 2379 | Internal | DCS operations |
| etcd Peer | 2380 | Internal | etcd replication |

Health check endpoint pattern:
```bash
curl http://10.0.0.11:8008/primary  # Returns 200 only on leader
curl http://10.0.0.11:8008/health   # Returns 200 if node is healthy
```

## Performance Tuning Philosophy

PostgreSQL settings scaled to hardware (see `.env.example`):

**16GB RAM baseline**:
- `shared_buffers=4GB` (25% of RAM)
- `effective_cache_size=12GB` (75% of RAM)
- `work_mem=40MB` (shared_buffers / max_connections * 4)

**PgBouncer pooling**:
- `max_client_conn=1000` (application connections)
- `default_pool_size=25` (backend connections per database)
- `pool_mode=transaction` (most efficient, statement-level not supported)

When modifying, recalculate `work_mem = shared_buffers / max_connections * 4` to prevent memory exhaustion.

## Common Pitfalls

1. **Forgetting to load `.env`**: Results in undefined variable errors. Always `set -a && source .env && set +a`
2. **Directly editing generated files**: Templates in `/etc/patroni/*.yml`, `/etc/pgbouncer/*.ini` are regenerated. Edit `.j2` templates instead
3. **Using `systemctl restart postgresql`**: Breaks Patroni state. Use `patronictl restart` instead
4. **Connecting to port 5432 in apps**: Bypasses connection pooling. Always use port 6432
5. **Modifying one node only**: Use `--limit` carefully. Most changes need cluster-wide coordination

## Key Files to Understand

- `inventory/group_vars/all.yml`: Central variable definitions (read this first)
- `roles/patroni/templates/patroni.yml.j2`: Patroni cluster configuration
- `roles/etcd/templates/etcd.conf.j2`: etcd cluster bootstrap
- `playbooks/site.yml`: Deployment orchestration order
- `.env.example`: All tunable parameters with documentation

## Quick Reference Commands

```bash
# Deploy full cluster
set -a && source .env && set +a
ansible-playbook playbooks/site.yml -i inventory/hosts.yml

# Check cluster status
ssh root@$NODE1_IP "patronictl -c /etc/patroni/patroni.yml list"

# Switchover to specific node
ansible-playbook playbooks/switchover.yml -e "target_node=node2"

# Test configuration syntax
ansible-playbook playbooks/site.yml --syntax-check

# Dry run with changes preview
ansible-playbook playbooks/site.yml --check --diff

# Execute specific role only
ansible-playbook playbooks/site.yml --tags "pgbouncer"
```

## Version Constraints

- PostgreSQL: 18.x (hardcoded in role, update `POSTGRESQL_VERSION` and paths)
- Patroni: 4.1.x (pip installed with etcd extras)
- etcd: 3.5.x (binary download from GitHub releases)
- Target OS: Ubuntu 22.04 LTS / Debian 12 / Rocky Linux 9
- Ansible: >= 2.12 (uses `ansible.builtin` collections)

When updating component versions, check:
1. Binary paths in `*_BIN_DIR` variables
2. systemd service templates compatibility
3. Configuration file format changes

## Infrastructure Topology

| Host | Role | Specs |
|------|------|-------|
| `pg-node1` (`$NODE1_IP`) | PostgreSQL + Patroni + etcd + PgBouncer | 6 vCPU / 16 GB RAM |
| `pg-node2` (`$NODE2_IP`) | PostgreSQL + Patroni + etcd + PgBouncer | 6 vCPU / 16 GB RAM |
| `pg-node3` (`$NODE3_IP`) | PostgreSQL + Patroni + etcd + PgBouncer | 6 vCPU / 16 GB RAM |
| `pg-backup` (`$BACKUP_SERVER_IP`) | Dedicated backup server (pgBackRest) | 4 vCPU / 8 GB RAM |
| `monitoring` (`$MONITORING_SERVER_IP`) | Prometheus + Grafana | 4 vCPU / 8 GB RAM |

All IPs are defined **exclusively in `.env`** (gitignored). Inventory `hosts.yml` reads them via `lookup('env', 'VAR_NAME')`.

## Security: No Hardcoded IPs

**NEVER hardcode real IP addresses** in any file that gets committed to git. This includes:
- `inventory/hosts.yml` and `hosts.yml.example` — use `lookup('env', ...)` 
- `inventory/group_vars/all.yml` — defaults must use placeholder IPs (`10.0.0.x`)
- `.env.example` — use placeholder IPs (`10.0.0.x`), never real ones
- Documentation (`.md` files) — use `$NODE1_IP`, `$CLUSTER_NETWORK` env var references
- Scripts — use env vars (`$NODE1_IP`) or accept parameters, never hardcode

**Only `.env`** (which is in `.gitignore`) should contain real IP addresses.

### Environment Variables for IPs

```bash
# .env — the ONLY place with real IPs
NODE1_IP=<real-ip>        NODE1_NAME=pg-node1
NODE2_IP=<real-ip>        NODE2_NAME=pg-node2
NODE3_IP=<real-ip>        NODE3_NAME=pg-node3
BACKUP_SERVER_IP=<real-ip>      BACKUP_SERVER_NAME=pg-backup
MONITORING_SERVER_IP=<real-ip>  MONITORING_SERVER_NAME=monitoring
CLUSTER_NETWORK=<real-cidr>     CLUSTER_NETMASK=255.255.255.0
```
