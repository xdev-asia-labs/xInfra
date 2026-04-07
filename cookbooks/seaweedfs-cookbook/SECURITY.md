# Security Checklist for SeaweedFS

## ✅ Completed by Ansible Playbook

- [x] S3 API Authentication (Access Key + Secret Key)
- [x] UFW Firewall configuration
- [x] Restricted access to SeaweedFS ports (only from nginx server)
- [x] Services running as non-root user (seaweedfs)
- [x] Proper file permissions on config files (0600 for S3 config)

## 🔒 Additional Security Recommendations

### 1. Change Default Credentials (REQUIRED)

Update in `group_vars/all.yml`:

```yaml
s3_admin_access_key: "YOUR_STRONG_ACCESS_KEY_HERE"
s3_admin_secret_key: "YOUR_STRONG_SECRET_KEY_MIN_40_CHARS"
```

Then redeploy:

```bash
./deploy.sh
```

### 2. Update nginx_server_ip (REQUIRED)

Set the IP of your external nginx server in `group_vars/all.yml`:

```yaml
nginx_server_ip: "YOUR_NGINX_SERVER_IP"
```

Then redeploy to apply firewall rules:

```bash
./deploy.sh
```

### 3. Enable HTTPS on Nginx (HIGHLY RECOMMENDED)

```bash
# On nginx server
sudo certbot --nginx -d s3.yourdomain.com -d filer.yourdomain.com
```

See `nginx.conf.example` for SSL configuration.

### 4. Add Basic Auth for Master UI (RECOMMENDED)

```bash
# On nginx server
sudo htpasswd -c /etc/nginx/.htpasswd admin
```

Add to nginx config:

```nginx
server {
    server_name master.yourdomain.com;
    
    auth_basic "Restricted Access";
    auth_basic_user_file /etc/nginx/.htpasswd;
    
    location / {
        proxy_pass http://seaweedfs_master;
    }
}
```

### 5. Configure Multiple S3 Users (OPTIONAL)

Edit `/etc/seaweedfs/s3.config.json` on SeaweedFS server:

```json
{
  "identities": [
    {
      "name": "admin",
      "credentials": [{"accessKey": "admin_key", "secretKey": "admin_secret"}],
      "actions": ["Admin", "Read", "List", "Tagging", "Write"]
    },
    {
      "name": "readonly",
      "credentials": [{"accessKey": "readonly_key", "secretKey": "readonly_secret"}],
      "actions": ["Read", "List"]
    },
    {
      "name": "app_user",
      "credentials": [{"accessKey": "app_key", "secretKey": "app_secret"}],
      "actions": ["Read", "Write", "List"]
    }
  ]
}
```

Restart S3 service:

```bash
sudo systemctl restart seaweedfs-s3
```

### 6. Rate Limiting on Nginx (RECOMMENDED)

Add to nginx config:

```nginx
http {
    limit_req_zone $binary_remote_addr zone=s3_limit:10m rate=10r/s;
    
    server {
        location / {
            limit_req zone=s3_limit burst=20 nodelay;
        }
    }
}
```

### 7. IP Whitelisting (OPTIONAL)

If you know the client IPs, add to nginx:

```nginx
server {
    location / {
        allow 192.168.1.0/24;
        allow 10.0.0.0/8;
        deny all;
    }
}
```

### 8. Disable Direct Access (RECOMMENDED)

If using nginx reverse proxy, you can configure UFW to ONLY allow nginx server:

```bash
# On SeaweedFS server
sudo ufw delete allow 9333
sudo ufw delete allow 8080
sudo ufw delete allow 8888
sudo ufw delete allow 8333

# Only allow from nginx server (already done by playbook if nginx_server_ip is set)
```

### 9. Enable Audit Logging (OPTIONAL)

For S3 API, you can enable audit logging. Add to S3 service:

Edit `roles/seaweedfs/templates/seaweedfs-s3.service.j2`:

```
ExecStart=/usr/local/bin/weed s3 \
  -ip.bind=0.0.0.0 \
  -port=8333 \
  -filer=localhost:8888 \
  -config=/etc/seaweedfs/s3.config.json \
  -auditLogConfig=/etc/seaweedfs/s3-audit.json
```

Create audit config `/etc/seaweedfs/s3-audit.json`:

```json
{
  "logMode": "file",
  "filePath": "/var/log/seaweedfs/s3-audit.log",
  "maxSize": 100,
  "maxBackups": 10,
  "maxAge": 30
}
```

### 10. Regular Security Updates

```bash
# Update system packages regularly
sudo apt update && sudo apt upgrade -y

# Check for SeaweedFS updates
# Update seaweedfs_version in group_vars/all.yml
# Then redeploy
```

### 11. Backup Encryption (RECOMMENDED)

When backing up data, encrypt it:

```bash
# Backup with encryption
sudo tar -czf - /data/seaweedfs/ | \
  gpg --symmetric --cipher-algo AES256 \
  -o seaweedfs-backup-$(date +%Y%m%d).tar.gz.gpg
```

### 12. Monitor Logs (RECOMMENDED)

Set up log monitoring for suspicious activity:

```bash
# Watch S3 access logs
tail -f /var/log/seaweedfs/s3.log

# Watch for errors
tail -f /var/log/seaweedfs/*.error.log
```

### 13. Disable Unused Services (OPTIONAL)

If you only need S3 API:

```bash
# Stop and disable other services
sudo systemctl stop seaweedfs-master
sudo systemctl disable seaweedfs-master
# Keep only what you need
```

## Security Verification Checklist

After deployment, verify:

- [ ] S3 credentials have been changed from defaults
- [ ] nginx_server_ip is set correctly
- [ ] Firewall is enabled: `sudo ufw status`
- [ ] Only required ports are open
- [ ] HTTPS is configured on nginx
- [ ] S3 authentication works correctly
- [ ] Direct access to ports (except SSH) is blocked
- [ ] Services are running as non-root user
- [ ] Log rotation is configured
- [ ] Backups are scheduled

## Quick Security Test

```bash
# From external machine (not nginx server)
# These should timeout or be refused:
curl http://172.23.202.50:9333  # Should fail
curl http://172.23.202.50:8333  # Should fail

# From nginx server
# These should work:
curl http://172.23.202.50:9333  # Should work
curl http://172.23.202.50:8333  # Should work

# S3 API should require authentication
aws s3 --endpoint-url http://s3.yourdomain.com ls  # Should work with valid credentials
```
