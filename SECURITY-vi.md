# Hướng dẫn Bảo mật

🇬🇧 [English Version](SECURITY.md)

## Tổng quan

Tài liệu này mô tả các tính năng bảo mật và biện pháp tăng cường đã triển khai trong hệ thống PostgreSQL HA cluster. **BẢO MẬT LÀ ƯU TIÊN SỐ 1** - hãy làm theo hướng dẫn này cẩn thận cho môi trường production.

## 🔒 Tính năng Bảo mật Mặc định

### 1. **Xác thực PostgreSQL**

✅ Xác thực **SCRAM-SHA-256** (tiêu chuẩn ngành, thay thế MD5 đã lỗi thời)

- Tất cả kết nối sử dụng thuật toán hash `scram-sha-256`
- Mật khẩu không bao giờ truyền dạng rõ (cleartext)
- Chống tấn công rainbow table

### 2. **Kiểm soát Truy cập Mạng**

✅ Quy tắc **pg_hba.conf hạn chế**:

```
# ❌ ĐÃ XÓA: host all all 0.0.0.0/0 md5 (NGUY HIỂM!)
# ✅ AN TOÀN: Chỉ cho phép mạng cluster
- host all all <CLUSTER_NETWORK> scram-sha-256
```

**Hành vi mặc định**: Chỉ các node trong `CLUSTER_NETWORK` (vd: 10.0.0.0/24) mới kết nối được PostgreSQL.

### 3. **Mã hóa SSL/TLS**

✅ **PostgreSQL SSL bật mặc định** (`POSTGRESQL_SSL_ENABLED=true`)

- Mã hóa toàn bộ giao tiếp client-server
- Ngăn chặn nghe lén mật khẩu và tấn công man-in-the-middle
- Tự động tạo chứng chỉ tự ký (self-signed) nếu không cung cấp

### 4. **Xác thực Patroni REST API**

✅ **HTTP Basic Auth** bật mặc định:

```yaml
PATRONI_RESTAPI_AUTH_ENABLED=true
PATRONI_RESTAPI_USERNAME=patroni_admin
PATRONI_RESTAPI_PASSWORD=<mật_khẩu_mạnh>
```

**Endpoint được bảo vệ**: `/switchover`, `/failover`, `/restart`, `/reload`, `/reinitialize`

### 5. **Xác thực etcd**

✅ **etcd auth bật** (`ETCD_AUTH_ENABLED=true`)

- Yêu cầu mật khẩu root user
- Ngăn chặn thao tác trái phép trạng thái cluster
- **QUAN TRỌNG**: etcd lưu trữ tất cả secret và topology của cluster

### 6. **Bảo mật PgBouncer**

✅ Xác thực **SCRAM-SHA-256**:

```ini
auth_type = scram-sha-256
auth_query = SELECT usename, passwd FROM pg_shadow WHERE usename=$1
```

### 7. **Yêu cầu Mật khẩu Mạnh**

✅ **Bắt buộc mật khẩu phức tạp**:

- Tối thiểu 16 ký tự
- Kết hợp chữ hoa, chữ thường, số, ký tự đặc biệt
- Tạo bằng `openssl rand -base64 32`

## 🚨 Trạng thái CVE Quan trọng

### PostgreSQL 18.1 → Cần nâng cấp lên 18.2+

**CVE-2025-8714** (CVSS 8.8 CAO):

- Ảnh hưởng: pg_dump thực thi code tùy ý
- Tác động: Dump độc hại có thể thực thi code khi restore
- **Yêu cầu**: Nâng cấp PostgreSQL lên 18.2+ ngay lập tức

**CVE đã fix gần đây:**

- CVE-2025-4207: Lộ thống kê optimizer (18.5+)
- CVE-2025-1094: Lỗ hổng encoding GB18030 (18.3+)
- CVE-2024-10979: Bypass xác thực Quoting API (18.1+)
- CVE-2024-10978: Injection biến môi trường PL/Perl (18.1+)

## 🛡️ Checklist Bảo mật

### Trước triển khai

- [ ] **Tạo mật khẩu mạnh** cho tất cả tài khoản:

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

- [ ] **Cấu hình file `.env`** với mật khẩu đã tạo:

```bash
cp .env.example .env
nano .env
# Điền tất cả trường mật khẩu trống
```

- [ ] **Kiểm tra SSL đã bật**:

```bash
grep POSTGRESQL_SSL_ENABLED .env
# Phải là: POSTGRESQL_SSL_ENABLED=true
```

- [ ] **Kiểm tra xác thực đã bật**:

```bash
grep -E "(ETCD_AUTH_ENABLED|PATRONI_RESTAPI_AUTH_ENABLED)" .env
# Cả hai phải là: true
```

- [ ] **Kiểm tra cấu hình mạng**:

```bash
grep CLUSTER_NETWORK .env
# Đảm bảo khớp với subnet thực tế của cluster
```

### Sau triển khai

- [ ] **Test kết nối SSL**:

```bash
psql "postgresql://admin@<node-ip>:5432/postgres?sslmode=require"
```

- [ ] **Xác minh xác thực Patroni API**:

```bash
# Phải thất bại khi không có credentials
curl http://<node-ip>:8008/patroni

# Phải thành công với credentials
curl -u patroni_admin:<password> http://<node-ip>:8008/patroni
```

- [ ] **Kiểm tra firewall**:

```bash
ssh root@<node-ip> "ufw status"
# Xác minh chỉ các port cần thiết được mở
```

- [ ] **Kiểm tra quyền user**:

```bash
psql -U postgres -c "\du"
# Xác minh không có superuser ngoài ý muốn
```

- [ ] **Đổi mật khẩu Grafana** khi đăng nhập lần đầu

- [ ] **Bật audit logging** (tùy chọn nhưng nên bật):

```sql
ALTER SYSTEM SET log_connections = 'on';
ALTER SYSTEM SET log_disconnections = 'on';
ALTER SYSTEM SET log_statement = 'ddl';
SELECT pg_reload_conf();
```

## 🔥 Lỗi Bảo mật Thường gặp Cần Tránh

### ❌ KHÔNG LÀM

1. **Dùng mật khẩu yếu/mặc định**
   - ❌ `admin123`, `password`, `postgres`
   - ✅ Dùng `openssl rand -base64 32`

2. **Mở PostgreSQL ra internet**
   - ❌ `host all all 0.0.0.0/0 md5`
   - ✅ Giới hạn trong `CLUSTER_NETWORK`

3. **Tắt SSL trong production**
   - ❌ `POSTGRESQL_SSL_ENABLED=false`
   - ✅ Luôn bật SSL: `POSTGRESQL_SSL_ENABLED=true`

4. **Để Patroni API không bảo vệ**
   - ❌ `PATRONI_RESTAPI_AUTH_ENABLED=false`
   - ✅ Bật auth để ngăn failover trái phép

5. **Dùng xác thực MD5**
   - ❌ `PGBOUNCER_AUTH_TYPE=md5` (dễ bị tấn công rainbow table)
   - ✅ Dùng `scram-sha-256`

6. **Commit file `.env` lên git**
   - ❌ Chứa tất cả secret của cluster!
   - ✅ Đảm bảo `.env` nằm trong `.gitignore`

7. **Chạy với quyền root**
   - ❌ PostgreSQL, etcd nên có user riêng
   - ✅ Đã cấu hình sẵn user `postgres`, `etcd`

8. **Bỏ qua xác thực etcd**
   - ❌ Bất kỳ ai cũng đọc/ghi được trạng thái cluster
   - ✅ `ETCD_AUTH_ENABLED=true` là bắt buộc

## 🔐 Tăng cường Bảo mật Nâng cao

### 1. Quản lý Chứng chỉ SSL

**Cài đặt Production** - Dùng chứng chỉ do CA cấp:

```bash
# Tạo chứng chỉ CA
openssl req -new -x509 -days 3650 -nodes \
  -out /etc/postgresql/ssl/root.crt \
  -keyout /etc/postgresql/ssl/root.key \
  -subj "/CN=PostgreSQL-HA-CA"

# Tạo chứng chỉ server cho mỗi node
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

# Cài đặt quyền
chmod 600 /etc/postgresql/ssl/*.key
chown postgres:postgres /etc/postgresql/ssl/*
```

**Cập nhật `.env`:**

```bash
POSTGRESQL_SSL_CERT_FILE=/etc/postgresql/ssl/<node>.crt
POSTGRESQL_SSL_KEY_FILE=/etc/postgresql/ssl/<node>.key
POSTGRESQL_SSL_CA_FILE=/etc/postgresql/ssl/root.crt
```

### 2. Cấu hình TLS cho etcd

**Tạo chứng chỉ etcd:**

```bash
# Tạo thư mục SSL cho etcd
mkdir -p /etc/etcd/ssl

# Tạo CA cho etcd
openssl req -new -x509 -days 3650 -nodes \
  -out /etc/etcd/ssl/ca.crt \
  -keyout /etc/etcd/ssl/ca.key \
  -subj "/CN=etcd-CA"

# Tạo chứng chỉ server cho mỗi node
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

**Cập nhật etcd.conf.j2:**

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

### 3. HTTPS cho Prometheus/Grafana

**Nginx reverse proxy** với Let's Encrypt:

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

### 4. Phân đoạn Mạng

**Quy tắc Firewall** (ví dụ UFW):

```bash
# PostgreSQL - chỉ cluster nodes
ufw allow from $CLUSTER_NETWORK to any port 5432 proto tcp

# PgBouncer - chỉ application servers
ufw allow from <app_subnet>/24 to any port 6432 proto tcp

# etcd - chỉ cluster nodes
ufw allow from $CLUSTER_NETWORK to any port 2379,2380 proto tcp

# Patroni API - chỉ monitoring server
ufw allow from <monitoring_ip> to any port 8008 proto tcp

# Monitoring exporters - chỉ monitoring server
ufw allow from <monitoring_ip> to any port 9100,9187,9127 proto tcp

# Prometheus/Grafana - chỉ VPN hoặc IP tin cậy
ufw allow from <vpn_subnet>/24 to any port 9090,3000 proto tcp

# Bật firewall
ufw enable
```

### 5. Audit Logging

**Bật extension pgAudit**:

```sql
CREATE EXTENSION pgaudit;

ALTER SYSTEM SET pgaudit.log = 'all';
ALTER SYSTEM SET pgaudit.log_catalog = 'off';
ALTER SYSTEM SET pgaudit.log_parameter = 'on';
ALTER SYSTEM SET pgaudit.log_relation = 'on';

SELECT pg_reload_conf();
```

**Theo dõi log**:

```bash
tail -f /var/log/postgresql/postgresql-*.log | grep AUDIT
```

### 6. Phát hiện Xâm nhập

**Cài đặt fail2ban**:

```bash
apt install fail2ban

# Tạo /etc/fail2ban/filter.d/postgresql.conf
[Definition]
failregex = FATAL:  password authentication failed for user ".*" <HOST>
ignoreregex =

# Tạo /etc/fail2ban/jail.d/postgresql.conf
[postgresql]
enabled = true
port = 5432,6432
filter = postgresql
logpath = /var/log/postgresql/postgresql-*.log
maxretry = 5
bantime = 3600
```

### 7. Quản lý Secret

**Dùng Ansible Vault** để mã hóa `.env`:

```bash
# Mã hóa .env
ansible-vault encrypt .env

# Triển khai với vault password
ansible-playbook playbooks/site.yml --ask-vault-pass

# Giải mã để chỉnh sửa
ansible-vault decrypt .env
nano .env
ansible-vault encrypt .env
```

**Hoặc dùng HashiCorp Vault**:

```bash
# Lưu secret vào Vault
vault kv put secret/postgres/superuser password=$(openssl rand -base64 32)
vault kv put secret/postgres/replication password=$(openssl rand -base64 32)

# Truy xuất trong Ansible
vars:
  postgresql_superuser_password: "{{ lookup('hashi_vault', 'secret/postgres/superuser:password') }}"
```

## 📊 Giám sát Bảo mật

### Metrics cần Theo dõi

1. **Lần đăng nhập thất bại**:

```sql
SELECT count(*) FROM pg_stat_activity 
WHERE state = 'idle in transaction failed';
```

1. **Kết nối superuser**:

```sql
SELECT usename, client_addr, backend_start 
FROM pg_stat_activity 
WHERE usesysid = 10;
```

1. **Tỷ lệ kết nối SSL**:

```sql
SELECT 
  count(*) FILTER (WHERE ssl = true) AS ssl_connections,
  count(*) FILTER (WHERE ssl = false) AS non_ssl_connections
FROM pg_stat_ssl;
```

1. **Sự kiện failover Patroni**:

```bash
journalctl -u patroni | grep -i "failover"
```

### Quy tắc Cảnh báo

Xem `roles/prometheus/templates/alert_rules.yml.j2` cho:

- `PostgreSQLDown`
- `PostgreSQLTooManyConnections`
- `PatroniNoLeader`
- `EtcdNoLeader`
- `HighReplicationLag`

## 🆘 Phản ứng Sự cố

### Nghi ngờ Bị xâm nhập

1. **Đổi ngay tất cả mật khẩu**:

```bash
psql -U postgres -c "ALTER USER postgres PASSWORD '<mật_khẩu_mới>';"
psql -U postgres -c "ALTER USER replicator PASSWORD '<mật_khẩu_mới>';"
psql -U postgres -c "ALTER USER admin PASSWORD '<mật_khẩu_mới>';"
```

1. **Kiểm tra kết nối**:

```sql
SELECT pid, usename, client_addr, backend_start, state 
FROM pg_stat_activity 
WHERE client_addr IS NOT NULL;
```

1. **Ngắt kết nối đáng ngờ**:

```sql
SELECT pg_terminate_backend(pid) 
FROM pg_stat_activity 
WHERE client_addr = '<ip_đáng_ngờ>';
```

1. **Kiểm tra audit log**:

```bash
grep -i "authentication failed" /var/log/postgresql/*.log
grep -i "FATAL" /var/log/postgresql/*.log
```

1. **Tạm thời bật log kết nối**:

```sql
ALTER SYSTEM SET log_connections = 'on';
ALTER SYSTEM SET log_disconnections = 'on';
SELECT pg_reload_conf();
```

## 📚 Tuân thủ

### Yêu cầu GDPR/HIPAA

- ✅ **Mã hóa at rest**: Bật với LUKS/dm-crypt
- ✅ **Mã hóa in transit**: SSL/TLS đã bật
- ✅ **Kiểm soát truy cập**: SCRAM-SHA-256, hạn chế mạng
- ✅ **Audit logging**: Extension pgAudit
- ✅ **Lưu trữ dữ liệu**: Cấu hình trong Patroni
- ✅ **Quyền xóa dữ liệu**: Triển khai quy trình xóa dữ liệu

### Yêu cầu PCI-DSS

- ✅ **Yêu cầu 2.1**: Đổi mật khẩu mặc định (bắt buộc)
- ✅ **Yêu cầu 4**: Mã hóa truyền tải (SSL/TLS)
- ✅ **Yêu cầu 8**: ID người dùng duy nhất (không chia sẻ tài khoản)
- ✅ **Yêu cầu 10**: Theo dõi và giám sát truy cập (audit logging)

## 🔄 Tác vụ Bảo mật Định kỳ

### Hàng ngày

- [ ] Kiểm tra lần đăng nhập thất bại
- [ ] Kiểm tra mẫu kết nối bất thường
- [ ] Giám sát replication lag

### Hàng tuần

- [ ] Kiểm tra quyền user
- [ ] Kiểm tra cập nhật CVE
- [ ] Đổi khóa mã hóa backup

### Hàng tháng

- [ ] Đổi mật khẩu (tùy chọn, theo chính sách)
- [ ] Kiểm tra hạn chứng chỉ SSL
- [ ] Cập nhật bản vá bảo mật
- [ ] Kiểm tra audit log

### Hàng quý

- [ ] Kiểm toán bảo mật toàn diện
- [ ] Penetration testing
- [ ] Diễn tập khắc phục thảm họa
- [ ] Cập nhật tài liệu bảo mật

## 📞 Hỗ trợ

Báo cáo vấn đề bảo mật:

- PostgreSQL Security: <security@postgresql.org>
- CVE Database: <https://www.postgresql.org/support/security/>
- Project Issues: <https://github.com/xdev-asia-labs/postgres-patroni-etcd-install/issues>

**KHÔNG BAO GIỜ** công khai lỗ hổng bảo mật. Báo cáo riêng tư trước.
