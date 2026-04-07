# SeaweedFS Ansible Deployment - Single Node

Ansible playbook for deploying SeaweedFS on a single node.

## Requirements

- Ansible 2.9+
- Linux Server (Ubuntu/Debian or CentOS/RHEL)
- Python 3.x on target host
- sudo/root privileges

## Directory Structure

```
.
├── ansible.cfg                          # Ansible configuration
├── playbook.yml                         # Main playbook
├── .env                                 # Environment config file (create from .env.example)
├── .env.example                         # Configuration template
├── load_env.sh                          # Script to load variables from .env
├── deploy.sh                            # Quick deployment script
├── nginx.conf.example                   # Nginx reverse proxy configuration
├── inventory/
│   └── hosts.ini                        # Inventory file (auto-generated)
├── group_vars/
│   └── all.yml                          # Configuration variables (auto-generated)
└── roles/
    └── seaweedfs/
        ├── tasks/
        │   └── main.yml                 # Main tasks
        ├── handlers/
        │   └── main.yml                 # Handlers
        └── templates/
            ├── seaweedfs-master.service.j2
            ├── seaweedfs-volume.service.j2
            ├── seaweedfs-filer.service.j2
            ├── seaweedfs-s3.service.j2
            └── s3.config.json.j2        # S3 credentials configuration
```

## Installation

### 1. Configure .env file

Copy the template and edit configuration:

```bash
cp .env.example .env
vim .env
```

Update values in `.env`:

```bash
# Server Configuration
ANSIBLE_HOST=YOUR_SERVER_IP          # Your server IP
ANSIBLE_USER=root                     # SSH user
ANSIBLE_SSH_PRIVATE_KEY_FILE=~/.ssh/id_rsa  # SSH key

# SeaweedFS Version
SEAWEEDFS_VERSION=3.66               # Version to install

# Ports
MASTER_PORT=9333
VOLUME_PORT=8080
FILER_PORT=8888
S3_PORT=8333

# ... and other configurations
```

### 2. Deploy with automated script (Recommended)

```bash
# Deploy everything in one command
./deploy.sh

# Or with sudo password
./deploy.sh --ask-become-pass
```

The `deploy.sh` script will automatically:

- Load configuration from `.env`
- Generate `inventory/hosts.ini` and `group_vars/all.yml`
- Test connection
- Run playbook
- Display access information

### 3. Manual deployment (If you want step-by-step control)

```bash
# Load configuration from .env
./load_env.sh

# Test connection
ansible all -m ping

# Deploy SeaweedFS
ansible-playbook playbook.yml

# Or with sudo password
ansible-playbook playbook.yml --ask-become-pass
```

## Installed Services

1. **SeaweedFS Master** (port 9333)
   - Manages metadata and volume topology
   - Web UI: http://YOUR_SERVER_IP:9333

2. **SeaweedFS Volume** (port 8080)
   - Stores actual data
   - API endpoint: http://YOUR_SERVER_IP:8080

3. **SeaweedFS Filer** (port 8888)
   - Provides file system interface
   - Web UI: http://YOUR_SERVER_IP:8888

4. **SeaweedFS S3** (port 8333)
   - S3-compatible API gateway
   - S3 endpoint: http://YOUR_SERVER_IP:8333

## Service Management

```bash
# Check status
sudo systemctl status seaweedfs-master
sudo systemctl status seaweedfs-volume
sudo systemctl status seaweedfs-filer
sudo systemctl status seaweedfs-s3

# Stop/Start/Restart
sudo systemctl stop seaweedfs-master
sudo systemctl start seaweedfs-master
sudo systemctl restart seaweedfs-master

# View logs
sudo journalctl -u seaweedfs-master -f
tail -f /var/log/seaweedfs/master.log
```

## Testing

```bash
# Check cluster status
curl http://localhost:9333/cluster/status

# Check volume status
curl http://localhost:9333/dir/status

# Upload file test
curl -F file=@test.txt http://localhost:9333/submit

# S3 test with AWS CLI
aws s3 --endpoint-url http://localhost:8333 ls
```

## Security

### 1. S3 Authentication

S3 API is secured with Access Key and Secret Key. Credentials are configured in:

```bash
# File: /etc/seaweedfs/s3.config.json
{
  "identities": [
    {
      "name": "admin",
      "credentials": [
        {
          "accessKey": "your_access_key",
          "secretKey": "your_secret_key"
        }
      ],
      "actions": ["Admin", "Read", "List", "Tagging", "Write"]
    }
  ]
}
```

**Change default credentials:**

Update in `group_vars/all.yml`:

```yaml
s3_admin_access_key: "your_strong_access_key"
s3_admin_secret_key: "your_strong_secret_key_min_40_chars"
```

Then run playbook again to apply:

```bash
./deploy.sh
```

### 2. Firewall (UFW)

The playbook automatically configures UFW firewall to:

- Allow SSH (port 22) from anywhere
- Allow SeaweedFS ports (9333, 8080, 8888, 8333) only from nginx server

**Configure nginx server IP:**

Update in `group_vars/all.yml`:

```yaml
nginx_server_ip: "YOUR_NGINX_SERVER_IP"  # Example: "172.23.202.17"
```

**Check firewall:**

```bash
sudo ufw status verbose
```

### 3. Nginx Reverse Proxy (Recommended)

Use nginx as external reverse proxy for:

- SSL/TLS termination
- Load balancing
- Rate limiting
- Access control

See `nginx.conf.example` file for detailed configuration.

## Nginx Reverse Proxy Configuration

### Step 1: Prepare on nginx server

```bash
# Install nginx if not already installed
sudo apt update && sudo apt install nginx -y

# Create htpasswd for basic auth (optional)
sudo apt install apache2-utils -y
sudo htpasswd -c /etc/nginx/.htpasswd admin
```

### Step 2: Configure DNS

Point subdomains to nginx server IP:

```
master.yourdomain.com   -> NGINX_SERVER_IP
filer.yourdomain.com    -> NGINX_SERVER_IP  
s3.yourdomain.com       -> NGINX_SERVER_IP
```

### Step 3: Apply nginx configuration

Copy `nginx.conf.example` to nginx server and edit:

```bash
# On nginx server
sudo cp nginx.conf.example /etc/nginx/sites-available/seaweedfs
sudo ln -s /etc/nginx/sites-available/seaweedfs /etc/nginx/sites-enabled/

# Edit the file
sudo nano /etc/nginx/sites-available/seaweedfs

# Change:
# - 172.23.202.50 -> Your SeaweedFS server IP
# - yourdomain.com -> Your domain

# Test config
sudo nginx -t

# Reload nginx
sudo systemctl reload nginx
```

### Step 4: Install SSL with Let's Encrypt (Recommended)

```bash
# Install certbot
sudo apt install certbot python3-certbot-nginx -y

# Create certificate
sudo certbot --nginx -d s3.yourdomain.com -d filer.yourdomain.com

# Auto renewal
sudo certbot renew --dry-run
```

### Step 5: Test connection

```bash
# Test filer
curl http://filer.yourdomain.com/

# Test S3 API with AWS CLI
aws configure set aws_access_key_id your_access_key
aws configure set aws_secret_access_key your_secret_key
aws s3 --endpoint-url http://s3.yourdomain.com ls

# Upload test file
echo "test" > test.txt
aws s3 --endpoint-url http://s3.yourdomain.com cp test.txt s3://bucket-name/
```

### Advanced nginx configuration

**Rate limiting:**

```nginx
http {
    limit_req_zone $binary_remote_addr zone=s3_limit:10m rate=10r/s;
    
    server {
        location / {
            limit_req zone=s3_limit burst=20 nodelay;
            proxy_pass http://seaweedfs_s3;
        }
    }
}
```

**IP whitelist:**

```nginx
server {
    location / {
        allow 192.168.1.0/24;
        allow 10.0.0.0/8;
        deny all;
        
        proxy_pass http://seaweedfs_s3;
    }
}
```

**Basic authentication for Master UI:**

```nginx
server {
    listen 80;
    server_name master.yourdomain.com;
    
    auth_basic "Restricted Access";
    auth_basic_user_file /etc/nginx/.htpasswd;
    
    location / {
        proxy_pass http://seaweedfs_master;
    }
}
```

## Important Paths

- Binary: `/usr/local/bin/weed`
- Data: `/data/seaweedfs/`
- Logs: `/var/log/seaweedfs/`
- Services: `/etc/systemd/system/seaweedfs-*.service`
- S3 Config: `/etc/seaweedfs/s3.config.json`

## Using S3 API

### With AWS CLI

```bash
# Configure
aws configure set aws_access_key_id admin_access_key_123
aws configure set aws_secret_access_key admin_secret_key_456_change_this

# Create bucket
aws s3 --endpoint-url http://s3.yourdomain.com mb s3://mybucket

# List buckets
aws s3 --endpoint-url http://s3.yourdomain.com ls

# Upload file
aws s3 --endpoint-url http://s3.yourdomain.com cp file.txt s3://mybucket/

# Download file
aws s3 --endpoint-url http://s3.yourdomain.com cp s3://mybucket/file.txt .

# Sync directory
aws s3 --endpoint-url http://s3.yourdomain.com sync ./local-dir s3://mybucket/remote-dir/
```

### With Python boto3

```python
import boto3

# Create client
s3 = boto3.client(
    's3',
    endpoint_url='http://s3.yourdomain.com',
    aws_access_key_id='admin_access_key_123',
    aws_secret_access_key='admin_secret_key_456_change_this'
)

# Create bucket
s3.create_bucket(Bucket='mybucket')

# Upload file
s3.upload_file('local-file.txt', 'mybucket', 'remote-file.txt')

# Download file
s3.download_file('mybucket', 'remote-file.txt', 'downloaded-file.txt')

# List objects
response = s3.list_objects_v2(Bucket='mybucket')
for obj in response.get('Contents', []):
    print(obj['Key'])
```

### With cURL

```bash
# List buckets (requires proper AWS signature)
# Recommend using AWS CLI or SDK instead of direct curl
```

## Troubleshooting

### Service won't start

```bash
# Check logs
sudo journalctl -u seaweedfs-master -n 50
sudo journalctl -u seaweedfs-volume -n 50
sudo journalctl -u seaweedfs-filer -n 50
sudo journalctl -u seaweedfs-s3 -n 50

# Check error logs
tail -f /var/log/seaweedfs/master.error.log
tail -f /var/log/seaweedfs/volume.error.log
tail -f /var/log/seaweedfs/filer.error.log
tail -f /var/log/seaweedfs/s3.error.log
```

### Port conflicts

```bash
# Check if ports are in use
sudo ss -tlnp | grep -E '(9333|8080|8888|8333)'

# Stop conflicting services
sudo systemctl stop <service-name>
```

### Firewall issues

```bash
# Check firewall status
sudo ufw status verbose

# Temporarily disable to test
sudo ufw disable

# Re-enable after testing
sudo ufw enable
```

### S3 authentication fails

```bash
# Verify S3 config
cat /etc/seaweedfs/s3.config.json

# Check S3 service logs
sudo journalctl -u seaweedfs-s3 -f

# Restart S3 service
sudo systemctl restart seaweedfs-s3
```

### Connection refused from nginx

```bash
# Check if SeaweedFS services are listening on 0.0.0.0
sudo ss -tlnp | grep weed

# Should see:
# *:9333   (Master)
# *:8080   (Volume)
# *:8888   (Filer)
# *:8333   (S3)

# If not, check service configuration
sudo systemctl cat seaweedfs-master
```

## Performance Tuning

### Volume settings

```yaml
# In group_vars/all.yml
volume_max: 1000  # Increase max volumes
```

### Replication

```yaml
# Change replication type
default_replication: "001"  # 1 copy on different rack
# 000 = no replication
# 001 = 1 copy on different rack
# 010 = 1 copy in different data center
# 100 = 1 copy on different data center
# 200 = 2 copies in different data centers
```

### Master configuration

```bash
# Edit template: roles/seaweedfs/templates/seaweedfs-master.service.j2
# Add more options:
ExecStart=/usr/local/bin/weed master \
  -mdir=/data/seaweedfs/master \
  -ip=0.0.0.0 \
  -port=9333 \
  -defaultReplication=000 \
  -volumeSizeLimitMB=30000 \
  -pulseSeconds=5
```

## Monitoring

### Health checks

```bash
# Master health
curl http://localhost:9333/cluster/healthz

# Volume health  
curl http://localhost:8080/status

# Filer health
curl http://localhost:8888/
```

### Metrics (Prometheus format)

```bash
# Master metrics
curl http://localhost:9333/metrics

# Volume metrics
curl http://localhost:8080/metrics

# Filer metrics
curl http://localhost:8888/metrics
```

## Backup and Restore

### Backup metadata

```bash
# Backup master metadata
sudo tar -czf seaweedfs-master-backup-$(date +%Y%m%d).tar.gz /data/seaweedfs/master/

# Backup filer metadata
sudo tar -czf seaweedfs-filer-backup-$(date +%Y%m%d).tar.gz /data/seaweedfs/filer/
```

### Backup volumes

```bash
# Backup all volume data
sudo tar -czf seaweedfs-volumes-backup-$(date +%Y%m%d).tar.gz /data/seaweedfs/volume/
```

### Restore

```bash
# Stop services
sudo systemctl stop seaweedfs-master seaweedfs-volume seaweedfs-filer seaweedfs-s3

# Restore data
sudo tar -xzf seaweedfs-master-backup-20250101.tar.gz -C /
sudo tar -xzf seaweedfs-filer-backup-20250101.tar.gz -C /
sudo tar -xzf seaweedfs-volumes-backup-20250101.tar.gz -C /

# Fix permissions
sudo chown -R seaweedfs:seaweedfs /data/seaweedfs/

# Start services
sudo systemctl start seaweedfs-master seaweedfs-volume seaweedfs-filer seaweedfs-s3
```

## Uninstall

```bash
# Stop and disable services
sudo systemctl stop seaweedfs-master seaweedfs-volume seaweedfs-filer seaweedfs-s3
sudo systemctl disable seaweedfs-master seaweedfs-volume seaweedfs-filer seaweedfs-s3

# Remove services
sudo rm /etc/systemd/system/seaweedfs-*.service
sudo systemctl daemon-reload

# Remove data and logs (CAREFUL!)
sudo rm -rf /data/seaweedfs
sudo rm -rf /var/log/seaweedfs

# Remove binary
sudo rm /usr/local/bin/weed

# Remove user
sudo userdel seaweedfs
```

## References

- [SeaweedFS Documentation](https://github.com/seaweedfs/seaweedfs/wiki)
- [SeaweedFS Releases](https://github.com/seaweedfs/seaweedfs/releases)
