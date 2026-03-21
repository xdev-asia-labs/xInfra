# PostgreSQL HA Cluster - Monitoring Stack

## Overview

Full monitoring stack với **Prometheus + Grafana** để theo dõi PostgreSQL HA cluster.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Monitoring Stack                          │
│                                                              │
│  ┌──────────────┐         ┌──────────────┐                 │
│  │  Prometheus  │────────▶│   Grafana    │                 │
│  │   :9090      │         │    :3000     │                 │
│  └──────┬───────┘         └──────────────┘                 │
│         │                                                    │
│         │ scrape metrics                                     │
│         │                                                    │
└─────────┼────────────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────────────────────┐
│              PostgreSQL HA Cluster (3 nodes)                 │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ Node 1 (pg-node1)                                    │   │
│  │  • node_exporter:9100      (system metrics)         │   │
│  │  • postgres_exporter:9187  (database metrics)       │   │
│  │  • pgbouncer_exporter:9127 (pool metrics)           │   │
│  │  • patroni:8008/metrics    (HA metrics)             │   │
│  │  • etcd:2379/metrics       (DCS metrics)            │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ Node 2 (pg-node2) - Same exporters                  │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ Node 3 (pg-node3) - Same exporters                  │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## Components

### 1. **Prometheus** (Port 9090)

- Time-series database
- Scrapes metrics mỗi 15 giây
- Lưu trữ 30 ngày (configurable)
- Alert rules cho critical events

### 2. **Grafana** (Port 3000)

- Visualization dashboard
- Pre-configured dashboards:
  - PostgreSQL Overview
  - Patroni HA Cluster
  - System Metrics (Node Exporter)
  - etcd Cluster
- Alert notifications (optional)

### 3. **Exporters** (Trên mỗi PostgreSQL node)

- **node_exporter** (9100): CPU, RAM, Disk, Network
- **postgres_exporter** (9187): Connections, queries, replication lag
- **pgbouncer_exporter** (9127): Connection pool stats
- **patroni metrics** (8008): Leader/replica state, failover events
- **etcd metrics** (2379): Cluster health, leader changes

## Installation

### Step 1: Configure Environment

```bash
cd /path/to/postgres-patroni-etcd-install

# Copy và edit .env
cp .env.example .env
nano .env
```

**Key monitoring variables trong `.env`:**

```bash
# Enable/Disable Monitoring
MONITORING_ENABLED=true

# Monitoring Server (có thể là node riêng hoặc dùng 1 trong 3 postgres nodes)
MONITORING_SERVER_IP=10.0.0.22
MONITORING_SERVER_NAME=pg-node1

# Prometheus
PROMETHEUS_VERSION=3.0.1
PROMETHEUS_PORT=9090
PROMETHEUS_RETENTION_TIME=30d
PROMETHEUS_RETENTION_SIZE=50GB

# Grafana
GRAFANA_PORT=3000
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=ChangeMe@AdminPass#2024

# Exporters
NODE_EXPORTER_PORT=9100
POSTGRES_EXPORTER_PORT=9187
PGBOUNCER_EXPORTER_PORT=9127
```

**Lưu ý:**

- Set `MONITORING_ENABLED=true` để bật monitoring
- `MONITORING_SERVER_IP` và `MONITORING_SERVER_NAME` để chỉ định máy chủ monitoring riêng
- Nếu không có server riêng, có thể dùng `pg-node1` (hoặc node nào có tài nguyên dư)

### Step 2: Deploy Monitoring Stack

```bash
# Load environment
set -a && source .env && set +a

# Deploy full stack (recommended)
./scripts/deploy_monitoring.sh --all

# Hoặc deploy từng component
./scripts/deploy_monitoring.sh --exporters    # Chỉ exporters
./scripts/deploy_monitoring.sh --prometheus   # Chỉ Prometheus
./scripts/deploy_monitoring.sh --grafana      # Chỉ Grafana
```

### Step 3: Verify Deployment

```bash
# Check health của tất cả services
./scripts/deploy_monitoring.sh --check
```

Expected output:

```
✓ Prometheus is healthy
✓ Grafana is healthy
✓ Node Exporter is running (all nodes)
✓ PostgreSQL Exporter is running (all nodes)
✓ PgBouncer Exporter is running (all nodes)
```

## Access URLs

### Prometheus

```
URL: http://<node-ip>:9090
Targets: http://<node-ip>:9090/targets
Alerts: http://<node-ip>:9090/alerts
```

### Grafana

```
URL: http://<node-ip>:3000
Username: admin (default)
Password: Check GRAFANA_ADMIN_PASSWORD in .env
```

### Exporters (per node)

```
Node Exporter: http://<node-ip>:9100/metrics
PostgreSQL Exporter: http://<node-ip>:9187/metrics
PgBouncer Exporter: http://<node-ip>:9127/metrics
Patroni Metrics: http://<node-ip>:8008/metrics
etcd Metrics: http://<node-ip>:2379/metrics
```

## Grafana Dashboards

Sau khi login vào Grafana, có 4 dashboards pre-configured:

### 1. **PostgreSQL Overview**

- Database status (up/down)
- Active connections per database
- Replication lag
- Transaction rate (commits/rollbacks)
- Cache hit ratio
- Dead tuples count

### 2. **Patroni HA Cluster**

- Current leader node
- Cluster member states
- Timeline changes (failover events)
- DCS (etcd) connectivity

### 3. **Node Exporter - System Metrics**

- CPU usage per core
- Memory usage (total/available)
- Disk usage per mount point
- Network traffic (RX/TX)
- Disk I/O

### 4. **etcd Cluster**

- Leader status
- Leader change rate
- RPC traffic
- Disk sync duration

## Alert Rules

Prometheus có sẵn alert rules cho:

### Critical Alerts

- **PostgreSQLDown**: Database instance down > 1 minute
- **PatroniNoLeader**: Cluster không có leader > 1 minute
- **EtcdNoLeader**: etcd không có leader > 1 minute
- **NodeDown**: Server không respond > 2 minutes
- **PgBouncerDown**: Connection pooler down > 2 minutes

### Warning Alerts

- **PostgreSQLReplicationLag**: Lag > 60 seconds
- **PostgreSQLTooManyConnections**: > 80% max connections
- **HighCPUUsage**: CPU > 80% trong 5 minutes
- **HighMemoryUsage**: RAM > 85% trong 5 minutes
- **LowDiskSpace**: Disk < 15% free space

## Maintenance

### Update Exporters

```bash
# Update version trong .env
nano .env
# Change NODE_EXPORTER_VERSION, POSTGRES_EXPORTER_VERSION, etc.

# Re-deploy
set -a && source .env && set +a
./scripts/deploy_monitoring.sh --exporters
```

### Restart Services

```bash
# Prometheus
ssh root@<node-ip> "systemctl restart prometheus"

# Grafana
ssh root@<node-ip> "systemctl restart grafana-server"

# Exporters (per node)
ssh root@<node-ip> "systemctl restart node_exporter"
ssh root@<node-ip> "systemctl restart postgres_exporter"
ssh root@<node-ip> "systemctl restart pgbouncer_exporter"
```

### Check Logs

```bash
# Prometheus
ssh root@<node-ip> "journalctl -u prometheus -f"

# Grafana
ssh root@<node-ip> "journalctl -u grafana-server -f"

# Exporters
ssh root@<node-ip> "journalctl -u node_exporter -f"
ssh root@<node-ip> "journalctl -u postgres_exporter -f"
```

## Troubleshooting

### Prometheus không scrape được metrics

```bash
# Check firewall
ufw status

# Open ports if needed
ufw allow 9100/tcp  # node_exporter
ufw allow 9187/tcp  # postgres_exporter
ufw allow 9127/tcp  # pgbouncer_exporter
```

### PostgreSQL Exporter không connect được

```bash
# Check DSN trong /etc/default/postgres_exporter
cat /etc/default/postgres_exporter

# Test connection manually
psql "postgresql://admin:<password>@localhost:5432/postgres"

# Restart exporter
systemctl restart postgres_exporter
```

### Grafana không hiện dashboards

```bash
# Check provisioning directory
ls -la /var/lib/grafana/dashboards/

# Check Grafana logs
journalctl -u grafana-server -n 100
```

## Performance Impact

Monitoring stack có minimal impact:

| Component | CPU | RAM | Disk I/O |
|-----------|-----|-----|----------|
| Prometheus | <2% | ~1GB | Low |
| Grafana | <1% | ~200MB | Very Low |
| node_exporter | <0.5% | ~20MB | Very Low |
| postgres_exporter | <1% | ~50MB | Low |
| pgbouncer_exporter | <0.5% | ~20MB | Very Low |

**Total overhead per node:** ~2-3% CPU, ~100MB RAM

## Security Recommendations

1. **Change default Grafana password** trong `.env`
2. **Enable authentication** cho Prometheus nếu expose ra internet
3. **Use firewall** để restrict access đến monitoring ports
4. **Enable SSL/TLS** cho Grafana trong production
5. **Rotate secrets** trong `GRAFANA_SECRET_KEY`

## Integration với Alertmanager (Optional)

Nếu muốn gửi alerts qua Slack/Email:

```bash
# Install Alertmanager
# Set PROMETHEUS_ALERTMANAGER_TARGETS trong .env
PROMETHEUS_ALERTMANAGER_TARGETS=localhost:9093

# Re-deploy Prometheus
./scripts/deploy_monitoring.sh --prometheus
```

## Files Structure

```
roles/
├── prometheus/
│   ├── tasks/main.yml
│   ├── templates/
│   │   ├── prometheus.yml.j2
│   │   ├── prometheus.service.j2
│   │   └── alert_rules.yml.j2
│   ├── handlers/main.yml
│   └── defaults/main.yml
│
├── grafana/
│   ├── tasks/main.yml
│   ├── templates/
│   │   ├── grafana.ini.j2
│   │   ├── datasource.yml.j2
│   │   ├── dashboard_provisioning.yml.j2
│   │   └── dashboards/
│   │       ├── postgresql_dashboard.json.j2
│   │       ├── patroni_dashboard.json.j2
│   │       ├── node_exporter_dashboard.json.j2
│   │       └── etcd_dashboard.json.j2
│   ├── handlers/main.yml
│   └── defaults/main.yml
│
└── exporters/
    ├── tasks/main.yml
    ├── templates/
    │   ├── node_exporter.service.j2
    │   ├── postgres_exporter.service.j2
    │   ├── postgres_exporter.env.j2
    │   ├── pgbouncer_exporter.service.j2
    │   └── pgbouncer_exporter.env.j2
    ├── handlers/main.yml
    └── defaults/main.yml
```

## Additional Resources

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [PostgreSQL Exporter](https://github.com/prometheus-community/postgres_exporter)
- [Node Exporter](https://github.com/prometheus/node_exporter)
- [PgBouncer Exporter](https://github.com/prometheus-community/pgbouncer_exporter)
