<div align="center">

![PostgreSQL HA Cluster](assets/banner.jpeg)

# PostgreSQL High Availability với Patroni & etcd

### Tự động hóa Ansible cho Cluster Production

[![Ansible Lint](https://github.com/xdev-asia-labs/postgres-patroni-etcd-install/actions/workflows/ansible-lint.yml/badge.svg)](https://github.com/xdev-asia-labs/postgres-patroni-etcd-install/actions/workflows/ansible-lint.yml)
[![CI Pipeline](https://github.com/xdev-asia-labs/postgres-patroni-etcd-install/actions/workflows/ci.yml/badge.svg)](https://github.com/xdev-asia-labs/postgres-patroni-etcd-install/actions/workflows/ci.yml)
[![Documentation](https://github.com/xdev-asia-labs/postgres-patroni-etcd-install/actions/workflows/docs-check.yml/badge.svg)](https://github.com/xdev-asia-labs/postgres-patroni-etcd-install/actions/workflows/docs-check.yml)
[![Security Scan](https://github.com/xdev-asia-labs/postgres-patroni-etcd-install/actions/workflows/security.yml/badge.svg)](https://github.com/xdev-asia-labs/postgres-patroni-etcd-install/actions/workflows/security.yml)
[![Release](https://github.com/xdev-asia-labs/postgres-patroni-etcd-install/actions/workflows/release.yml/badge.svg)](https://github.com/xdev-asia-labs/postgres-patroni-etcd-install/actions/workflows/release.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-18.1-blue.svg)](https://www.postgresql.org/)
[![Patroni](https://img.shields.io/badge/Patroni-4.1.0-green.svg)](https://patroni.readthedocs.io/)

🇬🇧 [English Version](README.md)

</div>

Ansible playbooks để tự động hóa cài đặt và cấu hình PostgreSQL High Availability cluster sử dụng Patroni và etcd.

## 📋 Mục lục

- [Tính năng](#-tính-năng)
- [Kiến trúc](#-kiến-trúc)
- [Yêu cầu](#-yêu-cầu)
- [Bắt đầu nhanh](#-bắt-đầu-nhanh)
- [Cấu hình](#-cấu-hình)
- [Triển khai](#-triển-khai)
- [Kết nối ứng dụng](#-kết-nối-ứng-dụng)
- [Quản lý Cluster](#-quản-lý-cluster)
- [Giám sát](#-giám-sát)
- [Xử lý sự cố](#-xử-lý-sự-cố)
- [Tài liệu](#-tài-liệu)
- [Tham khảo](#-tham-khảo)

## 🚀 Tính năng

- ✅ **High Availability**: Tự động chuyển đổi dự phòng với Patroni (thời gian chuyển đổi 30-45 giây)
- ✅ **Distributed Configuration**: etcd cluster cho consensus và bầu chọn leader
- ✅ **Streaming Replication**: PostgreSQL 18.1 với hỗ trợ replication async/sync
- ✅ **Connection Pooling**: PgBouncer với khả năng multiplexing 13x (3000 client → 225 backend)
- ✅ **Multi-host Support**: Chuỗi kết nối JDBC/psycopg2/pg (không cần HAProxy)
- ✅ **Environment-based Config**: Toàn bộ cấu hình được tách ra file `.env`
- ✅ **Auto Recovery**: pg_rewind để tích hợp lại primary node bị lỗi
- ✅ **Production Ready**: Tối ưu cho RAM 16GB, SSD, hệ thống multi-core
- ✅ **Callback Scripts**: Giám sát và cảnh báo theo sự kiện

## 🏗️ Kiến trúc

```
┌─────────────────────────────────────────────────────────────────┐
│                      Tầng ứng dụng                              │
│  (Spring Boot / Python / Node.js / Java / .NET / etc.)         │
└──────────────┬──────────────┬──────────────┬───────────────────┘
               │              │              │
          Port 6432      Port 6432      Port 6432
               │              │              │
┌──────────────▼──────┐ ┌─────▼──────┐ ┌────▼───────────────────┐
│   PgBouncer (Node1) │ │ PgBouncer  │ │  PgBouncer (Node3)     │
│   Connection Pool   │ │   (Node2)  │ │  Connection Pool       │
│   Max: 1000 clients │ │            │ │  Max: 1000 clients     │
└──────────┬──────────┘ └─────┬──────┘ └────┬───────────────────┘
           │                  │              │
      Port 5432          Port 5432      Port 5432
           │                  │              │
┌──────────▼──────────┐ ┌─────▼──────┐ ┌────▼───────────────────┐
│  PostgreSQL 18.1    │ │ PostgreSQL │ │  PostgreSQL 18.1       │
│  Primary (Leader)   │ │  Replica   │ │  Replica               │
│  Read/Write         │ │  Read Only │ │  Read Only             │
└──────────┬──────────┘ └─────┬──────┘ └────┬───────────────────┘
           │                  │              │
      Port 8008          Port 8008      Port 8008
           │                  │              │
┌──────────▼──────────┐ ┌─────▼──────┐ ┌────▼───────────────────┐
│   Patroni 4.1.0     │ │  Patroni   │ │  Patroni 4.1.0         │
│   HA Manager        │ │ HA Manager │ │  HA Manager            │
└──────────┬──────────┘ └─────┬──────┘ └────┬───────────────────┘
           │                  │              │
      Port 2379          Port 2379      Port 2379
           │                  │              │
┌──────────▼──────────────────▼──────────────▼───────────────────┐
│                etcd 3.5.25 Cluster                              │
│          Distributed Configuration & Leader Election            │
│   Node1 (etcd1)  │  Node2 (etcd2)  │  Node3 (etcd3)           │
└─────────────────────────────────────────────────────────────────┘

Mạng: 10.0.0.0/24
  - pg-node1: 10.0.0.11
  - pg-node2: 10.0.0.12
  - pg-node3: 10.0.0.13
```

### Phiên bản các thành phần

| Thành phần | Phiên bản | Trạng thái |
|-----------|---------|--------|
| PostgreSQL | 18.1 | ✅ Production |
| Patroni | 4.1.0 | ✅ Production |
| etcd | 3.5.25 | ✅ Production |
| PgBouncer | 1.25.0 | ✅ Production |

## 📦 Yêu cầu

### Phần cứng (mỗi node)

**Tối thiểu (Lab/Dev)**:

- CPU: 2 cores
- RAM: 4 GB
- Disk: 20 GB (OS) + 20 GB (PostgreSQL data)
- Network: 1 Gbps

**Khuyến nghị (Production)**:

- CPU: 4-8 cores
- RAM: 16-32 GB
- Disk: 50 GB SSD (OS) + 100+ GB NVMe SSD (Data)
- Network: 10 Gbps

### Phần mềm

**Control Node (Ansible)**:

- Ansible >= 2.12
- Python >= 3.9

**Target Nodes**:

- Ubuntu 22.04 LTS / Debian 12 / Rocky Linux 9
- SSH access với quyền root hoặc sudo
- Python 3.x đã cài đặt

### Cổng mạng

| Dịch vụ | Cổng | Protocol | Truy cập | Mục đích |
|---------|------|----------|--------|---------|
| **PgBouncer** | **6432** | **TCP** | **Ứng dụng** | **Connection pooling (TRUY CẬP CHÍNH)** |
| PostgreSQL | 5432 | TCP | Nội bộ | Kết nối DB trực tiếp (admin/bảo trì) |
| Patroni REST API | 8008 | TCP | Nội bộ | Health checks, quản lý cluster |
| etcd client | 2379 | TCP | Nội bộ | Giao tiếp client-etcd |
| etcd peer | 2380 | TCP | Nội bộ | Replication etcd cluster |
| SSH | 22 | TCP | Admin | Quản trị từ xa |

**⚠️ Quan trọng**: Ứng dụng nên kết nối đến **PgBouncer (port 6432)**, KHÔNG phải PostgreSQL trực tiếp (port 5432).

## 🚀 Bắt đầu nhanh

### 1. Clone Repository

```bash
git clone https://github.com/xdev-asia-labs/postgres-patroni-etcd-install.git
cd postgres-patroni-etcd-install
```

### 2. Cấu hình biến môi trường

**Toàn bộ cấu hình cluster được tập trung trong file `.env`** (70+ biến).

```bash
# Copy template mẫu
cp .env.example .env

# Chỉnh sửa với cấu hình của bạn
nano .env  # hoặc vim, vi, code, etc.
```

**Các cấu hình quan trọng cần cập nhật:**

```bash
# Địa chỉ IP các Node
NODE1_IP=10.0.0.11
NODE2_IP=10.0.0.12
NODE3_IP=10.0.0.13

# Mật khẩu PostgreSQL (BẮT BUỘC - thay đổi ngay!)
POSTGRESQL_SUPERUSER_PASSWORD=mat_khau_manh_cua_ban
POSTGRESQL_REPLICATION_PASSWORD=mat_khau_manh_cua_ban
POSTGRESQL_ADMIN_PASSWORD=mat_khau_manh_cua_ban

# Mật khẩu Patroni REST API
PATRONI_RESTAPI_PASSWORD=mat_khau_admin_cua_ban

# Tối ưu hiệu năng (điều chỉnh theo phần cứng)
POSTGRESQL_SHARED_BUFFERS=4GB        # 25% RAM
POSTGRESQL_EFFECTIVE_CACHE_SIZE=12GB  # 75% RAM
POSTGRESQL_MAX_CONNECTIONS=100
PGBOUNCER_MAX_CLIENT_CONN=1000
```

### 3. Cấu hình Inventory

Chỉnh sửa `inventory/hosts.yml`:

```yaml
all:
  children:
    postgres:
      hosts:
        pg-node1:
          ansible_host: 10.0.0.11
          patroni_name: node1
          etcd_name: etcd1
        pg-node2:
          ansible_host: 10.0.0.12
          patroni_name: node2
          etcd_name: etcd2
        pg-node3:
          ansible_host: 10.0.0.13
          patroni_name: node3
          etcd_name: etcd3
```

### 4. Triển khai Cluster

**Load biến môi trường và triển khai:**

```bash
# Load biến .env (BẮT BUỘC trước khi chạy ansible)
set -a && source .env && set +a

# Triển khai toàn bộ cluster
ansible-playbook playbooks/site.yml -i inventory/hosts.yml

# Hoặc triển khai từng thành phần riêng
ansible-playbook playbooks/site.yml -i inventory/hosts.yml --tags postgresql
ansible-playbook playbooks/site.yml -i inventory/hosts.yml --tags etcd
ansible-playbook playbooks/site.yml -i inventory/hosts.yml --tags patroni
ansible-playbook playbooks/site.yml -i inventory/hosts.yml --tags pgbouncer
```

### 5. Kiểm tra triển khai

```bash
# Kiểm tra trạng thái Patroni cluster
ssh root@${NODE1_IP} "patronictl -c /etc/patroni/patroni.yml list"

# Kết quả mong đợi:
# + Cluster: postgres (7441307089994301601) ----+---------+----+-----------+
# | Member   | Host          | Role    | State   | TL | Lag in MB |
# +----------+---------------+---------+---------+----+-----------+
# | pg-node1 | 10.0.0.11 | Leader  | running |  2 |           |
# | pg-node2 | 10.0.0.12 | Replica | running |  2 |         0 |
# | pg-node3 | 10.0.0.13 | Replica | running |  2 |         0 |
# +----------+---------------+---------+---------+----+-----------+

# Kiểm tra sức khỏe etcd cluster
ETCDCTL_API=3 etcdctl --endpoints=http://${NODE1_IP}:2379,http://${NODE2_IP}:2379,http://${NODE3_IP}:2379 endpoint health

# Test kết nối PgBouncer
PGPASSWORD="${POSTGRESQL_SUPERUSER_PASSWORD}" psql -p 6432 -U postgres -h ${NODE1_IP} -c 'SELECT version();' postgres
```

## ⚙️ Cấu hình

### Biến môi trường (.env)

Tất cả cài đặt cluster được quản lý qua `.env`.

**Các nhóm biến (tổng 70+ biến):**

1. **Cấu hình mạng** (8 biến): IP, hostname, network/netmask
2. **Cấu hình PostgreSQL** (35+ biến): Phiên bản, cổng, mật khẩu, tối ưu hiệu năng
3. **Cấu hình etcd** (10 biến): Phiên bản, cổng, cấu hình cluster
4. **Cấu hình Patroni** (16 biến): HA configuration, DCS settings, REST API
5. **Cấu hình PgBouncer** (18 biến): Giới hạn pooling, timeout, logging
6. **Cấu hình hệ thống** (10 biến): Firewall, NTP, logging

**Load biến môi trường:**

```bash
# BẮT BUỘC trước khi chạy Ansible
set -a && source .env && set +a

# Xác minh đã load
echo "Node IPs: ${NODE1_IP}, ${NODE2_IP}, ${NODE3_IP}"
echo "PostgreSQL Version: ${POSTGRESQL_VERSION}"
```

### Tối ưu hiệu năng

Điều chỉnh theo phần cứng của bạn trong `.env`:

```bash
# Cho RAM 16GB (triển khai hiện tại)
POSTGRESQL_SHARED_BUFFERS=4GB
POSTGRESQL_EFFECTIVE_CACHE_SIZE=12GB
POSTGRESQL_WORK_MEM=40MB
POSTGRESQL_MAINTENANCE_WORK_MEM=1GB

# Cho RAM 32GB
POSTGRESQL_SHARED_BUFFERS=8GB
POSTGRESQL_EFFECTIVE_CACHE_SIZE=24GB
POSTGRESQL_WORK_MEM=80MB
POSTGRESQL_MAINTENANCE_WORK_MEM=2GB

# Cho RAM 64GB
POSTGRESQL_SHARED_BUFFERS=16GB
POSTGRESQL_EFFECTIVE_CACHE_SIZE=48GB
POSTGRESQL_WORK_MEM=160MB
POSTGRESQL_MAINTENANCE_WORK_MEM=4GB
```

## 🔌 Kết nối ứng dụng

**⚠️ QUAN TRỌNG**: Kết nối đến **PgBouncer (port 6432)**, KHÔNG phải PostgreSQL (port 5432).

### Lợi ích khi kết nối

- **Connection Pooling**: 3000 client → 225 backend connections (multiplexing 13x)
- **Automatic Failover**: Hỗ trợ multi-host JDBC/psycopg2/pg
- **Load Distribution**: Phân tải đều trên cả 3 node
- **Resource Efficiency**: Giảm overhead kết nối backend

### Chuỗi kết nối

#### Java / Spring Boot

```yaml
# application.yml
spring:
  datasource:
    url: jdbc:postgresql://10.0.0.11:6432,10.0.0.12:6432,10.0.0.13:6432/postgres?targetServerType=primary&loadBalanceHosts=true
    username: postgres
    password: ${POSTGRESQL_SUPERUSER_PASSWORD}
    hikari:
      maximum-pool-size: 20       # Pool ứng dụng (KHÔNG phải kết nối database)
      minimum-idle: 5
      connection-timeout: 30000
```

#### Python (psycopg2)

```python
import psycopg2
import os

conn = psycopg2.connect(
    host="10.0.0.11,10.0.0.12,10.0.0.13",
    port=6432,
    database="postgres",
    user="postgres",
    password=os.getenv('POSTGRESQL_SUPERUSER_PASSWORD'),
    target_session_attrs="read-write"
)
```

#### Node.js (pg)

```javascript
const { Pool } = require('pg');

const pool = new Pool({
  host: '10.0.0.11',          // Hoặc dùng multi-host
  port: 6432,
  database: 'postgres',
  user: 'postgres',
  password: process.env.POSTGRESQL_SUPERUSER_PASSWORD,
  max: 20,                        // Kích thước pool ứng dụng
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});
```

#### .NET (Npgsql)

```csharp
var connectionString = "Host=10.0.0.11,10.0.0.12,10.0.0.13;" +
                       "Port=6432;" +
                       "Database=postgres;" +
                       "Username=postgres;" +
                       "Password=your_password;" +
                       "Target Session Attributes=read-write;" +
                       "Load Balance Hosts=true;" +
                       "Maximum Pool Size=20;";
```

#### Go (pgx)

```go
connString := "postgres://postgres:password@10.0.0.11:6432,10.0.0.12:6432,10.0.0.13:6432/postgres?target_session_attrs=read-write"
pool, err := pgxpool.Connect(context.Background(), connString)
```

### Kết nối PostgreSQL trực tiếp (Chỉ dành cho Admin/Bảo trì)

Cho các tác vụ quản trị hoặc công cụ không hỗ trợ pooling:

```bash
# Kết nối single node (port 5432)
psql -h 10.0.0.11 -p 5432 -U postgres -d postgres

# JDBC với primary targeting
jdbc:postgresql://10.0.0.11:5432,10.0.0.12:5432,10.0.0.13:5432/postgres?targetServerType=primary
```

## 🔧 Quản lý Cluster

### Tạo Database Ứng dụng

Tạo databases và users từ cấu hình `APP_DATABASES` trong `.env`:

**1. Cấu hình trong `.env`:**

```bash
APP_DATABASES_ENABLED=true
APP_DATABASES='[
  {"name": "myapp_db", "user": "myapp_user", "password": "SecurePass@2024"},
  {"name": "another_db", "user": "another_user", "password": "AnotherPass@2024"}
]'
```

**2. Chạy playbook:**

```bash
set -a && source .env && set +a
ansible-playbook playbooks/create-database.yml -i inventory/hosts.yml
```

Playbook sẽ:

- Tạo database users với mật khẩu bảo mật
- Tạo databases với owner được chỉ định
- Cấp toàn bộ quyền trên databases
- Cập nhật PgBouncer userlist để connection pooling

**⚠️ Lưu ý**: Luôn kết nối qua PgBouncer (port 6432), KHÔNG phải PostgreSQL trực tiếp (port 5432).

### Lệnh Patroni

Tất cả lệnh thực thi trên bất kỳ node nào trong cluster:

```bash
# Kiểm tra trạng thái cluster
patronictll -c /etc/patroni/patroni.yml list

# Switchover (chuyển đổi leader có kế hoạch)
patronictl -c /etc/patroni/patroni.yml switchover --master pg-node1 --candidate pg-node2

# Failover (ép buộc leader mới)
patronictl -c /etc/patroni/patroni.yml failover --force

# Restart node
patronictl -c /etc/patroni/patroni.yml restart postgres pg-node2

# Reload cấu hình
patronictl -c /etc/patroni/patroni.yml reload postgres pg-node2

# Reinitialize node bị lỗi
patronictl -c /etc/patroni/patroni.yml reinit postgres pg-node2
```

### Switchover có kế hoạch

Dùng Ansible playbook để switchover có điều phối:

```bash
# Load môi trường
set -a && source .env && set +a

# Thực hiện switchover
ansible-playbook playbooks/switchover.yml -i inventory/hosts.yml
```

### Test Failover

```bash
# Stop Patroni trên leader hiện tại
ssh root@${NODE1_IP} "systemctl stop patroni"

# Chờ 30-45 giây để tự động failover
sleep 40

# Kiểm tra trạng thái cluster mới
ssh root@${NODE2_IP} "patronictl -c /etc/patroni/patroni.yml list"

# Khởi động lại node bị lỗi (tự động join như replica)
ssh root@${NODE1_IP} "systemctl start patroni"
```

### Rolling Updates

```bash
# Load môi trường
set -a && source .env && set +a

# Thực hiện rolling update
ansible-playbook playbooks/rolling-update.yml -i inventory/hosts.yml
```

### Thêm Replica mới

```bash
# Cập nhật inventory/hosts.yml với node mới trước

# Load môi trường
set -a && source .env && set +a

# Triển khai đến node mới
ansible-playbook playbooks/add-replica.yml -i inventory/hosts.yml
```

## 📊 Giám sát

### Health Check Endpoints

#### Patroni REST API

```bash
# Kiểm tra sức khỏe node (trả về 200 nếu healthy)
curl http://10.0.0.11:8008/health
curl http://10.0.0.12:8008/health
curl http://10.0.0.13:8008/health

# Kiểm tra xem node có phải primary không (chỉ trả về 200 trên leader)
curl http://10.0.0.11:8008/primary

# Kiểm tra xem node có phải replica không (chỉ trả về 200 trên replica)
curl http://10.0.0.12:8008/replica
curl http://10.0.0.13:8008/replica

# Lấy trạng thái cluster (JSON)
curl http://10.0.0.11:8008/patroni
```

#### Sức khỏe etcd Cluster

```bash
# Kiểm tra tất cả endpoints
ETCDCTL_API=3 etcdctl --endpoints=http://10.0.0.11:2379,http://10.0.0.12:2379,http://10.0.0.13:2379 endpoint health

# Kiểm tra trạng thái cluster
ETCDCTL_API=3 etcdctl --endpoints=http://10.0.0.11:2379 endpoint status --write-out=table

# Liệt kê thành viên etcd
ETCDCTL_API=3 etcdctl --endpoints=http://10.0.0.11:2379 member list
```

### Thống kê PgBouncer

```bash
# Kết nối đến console quản trị PgBouncer
PGPASSWORD="${POSTGRESQL_SUPERUSER_PASSWORD}" psql -p 6432 -U postgres -h 10.0.0.11 pgbouncer

# Lệnh quản trị:
SHOW POOLS;           # Xem connection pools
SHOW CLIENTS;         # Xem kết nối client
SHOW SERVERS;         # Xem kết nối server
SHOW DATABASES;       # Xem database đã cấu hình
SHOW STATS;           # Xem thống kê
SHOW CONFIG;          # Xem cấu hình
```

### Truy vấn giám sát PostgreSQL

```sql
-- Kiểm tra kết nối đang hoạt động
SELECT count(*) FROM pg_stat_activity;

-- Kết nối theo database
SELECT datname, count(*) FROM pg_stat_activity GROUP BY datname;

-- Trạng thái replication (trên primary)
SELECT * FROM pg_stat_replication;

-- Replication lag (trên primary)
SELECT 
  client_addr,
  state,
  pg_wal_lsn_diff(sent_lsn, replay_lsn) AS lag_bytes
FROM pg_stat_replication;

-- Kích thước database
SELECT 
  pg_database.datname,
  pg_size_pretty(pg_database_size(pg_database.datname)) AS size
FROM pg_database
ORDER BY pg_database_size(pg_database.datname) DESC;
```

### Log Files

```bash
# Log Patroni
ssh root@10.0.0.11 "journalctl -u patroni -f"

# Log etcd
ssh root@10.0.0.11 "journalctl -u etcd -f"

# Log PostgreSQL
ssh root@10.0.0.11 "tail -f /var/lib/postgresql/18/data/log/postgresql-*.log"

# Log PgBouncer
ssh root@10.0.0.11 "tail -f /var/log/pgbouncer/pgbouncer.log"
```

### Trạng thái dịch vụ

```bash
# Kiểm tra tất cả dịch vụ trên một node
ssh root@$NODE1_IP "
  systemctl status postgresql@18-main
  systemctl status patroni
  systemctl status etcd
  systemctl status pgbouncer
"
```

Xem **[CLUSTER_CONFIG.md](CLUSTER_CONFIG.md)** để biết thêm truy vấn và lệnh giám sát.

## 🛡️ Best Practices bảo mật

### 1. Quản lý mật khẩu

```bash
# Tạo mật khẩu mạnh
openssl rand -base64 32
pwgen -s 32 1

# Cập nhật .env với mật khẩu mạnh
POSTGRESQL_SUPERUSER_PASSWORD=$(openssl rand -base64 32)
POSTGRESQL_REPLICATION_PASSWORD=$(openssl rand -base64 32)
POSTGRESQL_ADMIN_PASSWORD=$(openssl rand -base64 32)
PATRONI_RESTAPI_PASSWORD=$(openssl rand -base64 32)

# Bảo mật quyền file .env
chmod 600 .env
chown $USER:$USER .env
```

### 2. Bảo mật File

```bash
# Không bao giờ commit .env vào git (đã có trong .gitignore)
git ls-files --cached .env  # Không nên trả về gì cả

# Dùng mật khẩu khác nhau cho mỗi môi trường
# .env.dev, .env.staging, .env.prod với mật khẩu khác nhau

# Rotate mật khẩu định kỳ (khuyến nghị hàng quý)
```

### 3. Bảo mật mạng

```bash
# Firewall rules (tự động cấu hình bởi Ansible)
# - Port 6432 (PgBouncer): Chỉ cho application servers
# - Port 5432 (PostgreSQL): Chỉ nội bộ cluster
# - Port 8008 (Patroni): Chỉ monitoring nội bộ
# - Port 2379-2380 (etcd): Chỉ nội bộ cluster

# Cấu hình UFW thủ công nếu cần:
ufw allow from 10.0.0.0/24 to any port 5432
ufw allow from <app_server_ip> to any port 6432
```

### 4. Bật xác thực (Production)

Cập nhật `.env` cho production:

```bash
# Bật xác thực Patroni REST API
PATRONI_RESTAPI_AUTH_ENABLED=true
PATRONI_RESTAPI_USERNAME=admin
PATRONI_RESTAPI_PASSWORD=mat_khau_manh_tai_day

# Bật xác thực etcd (tùy chọn)
ETCD_AUTH_ENABLED=true
ETCD_ROOT_PASSWORD=mat_khau_manh_tai_day
```

### 5. SSL/TLS (Tùy chọn)

```bash
# Bật PostgreSQL SSL
POSTGRESQL_SSL_ENABLED=true
POSTGRESQL_SSL_CERT_FILE=/path/to/server.crt
POSTGRESQL_SSL_KEY_FILE=/path/to/server.key
POSTGRESQL_SSL_CA_FILE=/path/to/ca.crt
```

## 🐛 Xử lý sự cố

### Vấn đề: Biến môi trường không load được

**Triệu chứng**: Ansible dùng giá trị mặc định thay vì giá trị từ .env

**Giải pháp**:

```bash
# Đảm bảo load trước khi chạy ansible
set -a && source .env && set +a

# Xác minh biến đã load
echo $NODE1_IP
echo $POSTGRESQL_VERSION

# Sau đó chạy ansible
ansible-playbook playbooks/site.yml -i inventory/hosts.yml
```

### Vấn đề: Patroni không khởi động được

**Triệu chứng**: `systemctl status patroni` hiển thị failed

**Giải pháp**:

```bash
# Kiểm tra logs
ssh root@10.0.0.11 "journalctl -u patroni -n 100"

# Validate cấu hình
ssh root@10.0.0.11 "python3 -c \"import yaml; yaml.safe_load(open('/etc/patroni/patroni.yml'))\""

# Kiểm tra kết nối etcd
ETCDCTL_API=3 etcdctl --endpoints=http://10.0.0.11:2379 endpoint health

# Xác minh PostgreSQL đã stop (Patroni quản lý nó)
ssh root@10.0.0.11 "systemctl stop postgresql@18-main"
ssh root@10.0.0.11 "systemctl disable postgresql@18-main"
```

### Vấn đề: etcd cluster không healthy

**Triệu chứng**: etcd endpoint health check thất bại

**Giải pháp**:

```bash
# Kiểm tra trạng thái etcd trên tất cả node
ETCDCTL_API=3 etcdctl --endpoints=http://10.0.0.11:2379,http://10.0.0.12:2379,http://10.0.0.13:2379 endpoint health

# Kiểm tra trạng thái từng node
ssh root@10.0.0.11 "systemctl status etcd"
ssh root@10.0.0.11 "journalctl -u etcd -n 50"

# Restart etcd nếu cần
ssh root@10.0.0.11 "systemctl restart etcd"

# Kiểm tra thành viên cluster
ETCDCTL_API=3 etcdctl --endpoints=http://10.0.0.11:2379 member list
```

### Vấn đề: Replication lag cao

**Triệu chứng**: Lag in MB > 0 trong `patronictl list`

**Giải pháp**:

```bash
# Kiểm tra trạng thái replication
ssh root@10.0.0.11 "psql -U postgres -c 'SELECT * FROM pg_stat_replication;'"

# Kiểm tra độ trễ mạng
ping -c 10 10.0.0.12

# Kiểm tra WAL retention
ssh root@10.0.0.11 "psql -U postgres -c 'SHOW wal_keep_size;'"

# Ép checkpoint để giảm lag
ssh root@10.0.0.11 "psql -U postgres -c 'CHECKPOINT;'"

# Kiểm tra disk I/O
ssh root@10.0.0.12 "iostat -x 2 5"
```

### Vấn đề: PgBouncer từ chối kết nối

**Triệu chứng**: Ứng dụng không thể kết nối port 6432

**Giải pháp**:

```bash
# Kiểm tra trạng thái PgBouncer
ssh root@10.0.0.11 "systemctl status pgbouncer"

# Kiểm tra logs
ssh root@10.0.0.11 "journalctl -u pgbouncer -f"

# Xác minh port đang lắng nghe
ssh root@10.0.0.11 "ss -tlnp | grep 6432"

# Test kết nối local
ssh root@10.0.0.11 "PGPASSWORD='${POSTGRESQL_SUPERUSER_PASSWORD}' psql -p 6432 -U postgres -h localhost postgres"

# Kiểm tra xác thực
ssh root@10.0.0.11 "cat /etc/pgbouncer/userlist.txt"
```

### Vấn đề: Split brain sau network partition

**Triệu chứng**: Nhiều node tự nhận là primary

**Giải pháp**:

```bash
# Kiểm tra node nào giữ leader key trong etcd
ETCDCTL_API=3 etcdctl --endpoints=http://10.0.0.11:2379 get /service/postgres/leader

# Kiểm tra trạng thái Patroni trên tất cả node
ssh root@10.0.0.11 "patronictl -c /etc/patroni/patroni.yml list"

# Nếu cần, ép buộc failover đến primary đúng
ssh root@10.0.0.11 "patronictl -c /etc/patroni/patroni.yml failover --force"

# Reinitialize replica không đồng bộ
ssh root@10.0.0.11 "patronictl -c /etc/patroni/patroni.yml reinit postgres pg-node2"
```

### Vấn đề: Triển khai thất bại với apt lock

**Triệu chứng**: "Could not get lock /var/lib/dpkg/lock"

**Giải pháp**:

```bash
# Kiểm tra tiến trình apt đang chạy
ssh root@10.0.0.11 "ps aux | grep -i apt"

# Kill unattended-upgrades nếu đang block
ssh root@10.0.0.11 "systemctl stop unattended-upgrades"
ssh root@10.0.0.11 "killall apt apt-get"

# Xóa lock
ssh root@10.0.0.11 "rm -f /var/lib/apt/lists/lock /var/cache/apt/archives/lock /var/lib/dpkg/lock*"

# Chạy lại Ansible
set -a && source .env && set +a
ansible-playbook playbooks/site.yml -i inventory/hosts.yml
```

Để biết thêm hướng dẫn xử lý sự cố, xem **[CLUSTER_CONFIG.md](CLUSTER_CONFIG.md)**.

## 📚 Tài liệu

Dự án này bao gồm tài liệu đầy đủ:

### Tài liệu chính

- **[README.md](README.md)** - Tài liệu tiếng Anh
- **[README-vi.md](README-vi.md)** - File này (tiếng Việt)

### Tài liệu kỹ thuật

- **[CLUSTER_CONFIG.md](CLUSTER_CONFIG.md)** (20KB)
  - Kiến trúc và cấu hình cluster đầy đủ
  - Thông số phần cứng và đặc điểm hiệu năng
  - Chuỗi kết nối cho tất cả ngôn ngữ (Java, Python, Node.js, .NET, Go)
  - Lệnh quản lý (Patroni, etcd, PgBouncer, PostgreSQL)
  - Truy vấn giám sát và health checks
  - Hướng dẫn xử lý sự cố chi tiết

- **[ENV_CONFIG_GUIDE.md](ENV_CONFIG_GUIDE.md)** (10KB)
  - Hướng dẫn đầy đủ về cấu hình `.env`
  - Giải thích 70+ biến môi trường
  - Tối ưu hiệu năng cho phần cứng khác nhau (16GB, 32GB, 64GB RAM)
  - Cấu hình theo môi trường (dev/staging/prod)
  - Best practices bảo mật
  - Xử lý sự cố thường gặp

### Tham khảo nhanh

| Tài liệu | Mục đích | Kích thước |
|----------|---------|------|
| README.md | Bắt đầu nhanh và tổng quan (Tiếng Anh) | 15KB |
| README-vi.md | Tài liệu tiếng Việt | 15KB |
| CLUSTER_CONFIG.md | Tài liệu kỹ thuật đầy đủ | 20KB |
| ENV_CONFIG_GUIDE.md | Hướng dẫn cấu hình môi trường | 10KB |
| .env.example | Template cấu hình | 7KB |

## 🎯 Tóm tắt tính năng chính

### High Availability

- **Automatic Failover**: Thời gian chuyển đổi 30-45 giây với Patroni
- **Zero Data Loss**: Hỗ trợ synchronous replication (tùy chọn)
- **Auto Recovery**: pg_rewind để tích hợp lại primary node bị lỗi
- **Health Monitoring**: REST API endpoints cho load balancers

### Hiệu năng

- **Connection Pooling**: PgBouncer với multiplexing 13x (3000 → 225 kết nối)
- **Tối ưu SSD**: `random_page_cost=1.1`, `effective_io_concurrency=200`
- **Parallel Queries**: Khớp với số CPU cores để tối ưu hiệu năng
- **Memory Tuning**: Tối ưu cho RAM 16GB (có thể mở rộng đến 64GB+)

### Xuất sắc vận hành

- **Single Source of Truth**: Tất cả 70+ biến cấu hình trong `.env`
- **Multi-Environment**: Dễ dàng chuyển đổi giữa dev/staging/prod
- **Version Control Friendly**: `.env` gitignored, `.env.example` committed
- **Tài liệu đầy đủ**: 45KB+ tài liệu bao quát mọi khía cạnh

### Production Ready

- **Battle Tested**: PostgreSQL 18.1, Patroni 4.1.0, etcd 3.5.25
- **Tập trung bảo mật**: Xác thực MD5, firewall rules, quản lý mật khẩu
- **Monitoring Ready**: Metrics tương thích Prometheus, health endpoints
- **Hỗ trợ Backup**: Sẵn sàng tích hợp pgBackRest, Barman, hoặc WAL-G

## 🚀 Đặc điểm hiệu năng

### Triển khai hiện tại (RAM 16GB/node)

```yaml
Phần cứng:
  CPU: ~5 cores/node (16 cores tổng)
  RAM: 16 GB/node (48 GB tổng)
  Disk: 200 GB SSD/node (600 GB tổng)
  Network: 1 Gbps trên 10.0.0.0/24

Khả năng kết nối:
  Client Connections: 3,000 max (1,000/node)
  Backend Connections: 225 điển hình, 300 max
  Hiệu quả Multiplexing: 13x

Hiệu năng dự kiến:
  Read Queries: 50,000-100,000 QPS (phân tán)
  Write Queries: 10,000-20,000 QPS (chỉ primary)
  Mixed Workload: 30,000-50,000 QPS
  Query Latency: <5ms (đơn giản), varies (phức tạp)
  Failover Time: 30-45 giây điển hình
```

## 📋 Checklist triển khai

- [ ] Clone repository
- [ ] Copy `.env.example` thành `.env`
- [ ] Cập nhật mật khẩu trong `.env` (QUAN TRỌNG)
- [ ] Cập nhật IP các node trong `.env`
- [ ] Điều chỉnh cấu hình hiệu năng theo phần cứng
- [ ] Cấu hình `inventory/hosts.yml`
- [ ] Load môi trường: `set -a && source .env && set +a`
- [ ] Triển khai cluster: `ansible-playbook playbooks/site.yml -i inventory/hosts.yml`
- [ ] Xác minh Patroni cluster: `patronictl list`
- [ ] Xác minh sức khỏe etcd: `etcdctl endpoint health`
- [ ] Test kết nối PgBouncer: `psql -p 6432`
- [ ] Cập nhật chuỗi kết nối ứng dụng (port 6432)
- [ ] Test kết nối ứng dụng
- [ ] Thiết lập monitoring/alerting
- [ ] Lên lịch backup
- [ ] Tài liệu hóa runbooks

## 🔗 Tham khảo bên ngoài

- [PostgreSQL 18 Documentation](https://www.postgresql.org/docs/18/)
- [Patroni Documentation](https://patroni.readthedocs.io/)
- [etcd Documentation](https://etcd.io/docs/)
- [PgBouncer Documentation](https://www.pgbouncer.org/)
- [Ansible Documentation](https://docs.ansible.com/)

## 📝 Giấy phép

MIT License - Xem file [LICENSE](LICENSE) để biết chi tiết.

## 👥 Đóng góp

Chúng tôi hoan nghênh đóng góp! Vui lòng:

1. Fork repository
2. Tạo feature branch
3. Thực hiện thay đổi
4. Test kỹ lưỡng
5. Submit Pull Request

## 🆘 Hỗ trợ

- **Issues**: [GitHub Issues](https://github.com/xdev-asia-labs/postgres-patroni-etcd-install/issues)
- **Discussions**: [GitHub Discussions](https://github.com/xdev-asia-labs/postgres-patroni-etcd-install/discussions)

---

**Duy trì bởi**: [xdev.asia](https://xdev.asia)  
**Cập nhật lần cuối**: 25 tháng 11, 2025  
**Trạng thái Cluster**: ✅ Hoạt động hoàn toàn
