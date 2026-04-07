# RKE2 High Availability Cluster - Ansible Playbooks

Ansible playbooks for deploying a production-ready RKE2 Kubernetes cluster with High Availability (HA) configuration.

## 🚀 Quick Start

```bash
# 1. Clone repository
git clone <repository-url>
cd kubernetes-cookbook

# 2. Configure environment
cp .env.example .env
vim .env  # Edit configuration

# ⚠️ IMPORTANT: Update these credentials in .env
# - RKE2_TOKEN: Change to a strong random value

# 3. Configure inventory
cp inventory/hosts.yml.example inventory/hosts.yml
vim inventory/hosts.yml  # Add your server IPs and SSH credentials

# 4. Setup SSH keys (if not already done)
ssh-keygen -t rsa -b 4096
ssh-copy-id root@<master-ip>
ssh-copy-id root@<worker-ip>

# 5. Test connectivity
set -a && source .env && set +a
ansible -i inventory/hosts.yml all -m ping

# 6. Deploy RKE2 cluster
ansible-playbook -i inventory/hosts.yml site.yml

# 7. (Optional) Deploy monitoring stack
# Add monitoring VM to inventory/hosts.yml first
ansible-playbook -i inventory/hosts.yml monitoring.yml

# 8. Get kubeconfig
scp -i ~/.ssh/fci root@<master-ip>:/etc/rancher/rke2/rke2.yaml ~/.kube/rke2-config
# Edit the file and change server: https://127.0.0.1:6443 to your master IP
export KUBECONFIG=~/.kube/rke2-config
kubectl get nodes
```

## Overview

RKE2 (Rancher Kubernetes Engine 2) is a CNCF-certified Kubernetes distribution focused on security and compliance. These playbooks automate the deployment of an HA RKE2 cluster with multiple control plane nodes.

## 🎯 Features

- ✅ **RKE2 HA Cluster**: Multi-master Kubernetes cluster with etcd
- ✅ **Environment-based Configuration**: All settings via `.env` file
- ✅ **Secure Credentials Management**: Tokens not in git
- ✅ **Private Registry Support**: Multiple registry authentication
- ✅ **Automated Installation**: Complete cluster setup with Ansible

## System Requirements

### Minimum Hardware

**Master Nodes (Control Plane):**

- CPU: 2 cores
- RAM: 4GB
- Disk: 50GB
- Quantity: 1 node (minimum) or 3 nodes (for HA)

**Worker Nodes:**

- CPU: 2 cores
- RAM: 4GB
- Disk: 50GB
- Quantity: 2+ nodes

**Monitoring Node (Optional):**

| Cluster Size | CPU | RAM | Disk | Notes |
|--------------|-----|-----|------|-------|
| **Small** (1-5 nodes) | 2 cores | 4 GB | 50 GB | Testing/Dev |
| **Medium** (5-10 nodes) | 4 cores | 8 GB | 100 GB | **Recommended** |
| **Large** (10-30 nodes) | 8 cores | 16 GB | 200 GB SSD | Production |
| **Enterprise** (30+ nodes) | 16 cores | 32 GB | 500 GB SSD | High traffic |

**Resource breakdown:**

- **Prometheus**: ~1-2 GB RAM base + 2-4 GB per 1000 active series
- **Grafana**: ~500 MB - 1 GB RAM
- **Node Exporter**: ~50-100 MB RAM
- **Disk**: 30-day retention = ~1-5 GB per node depending on scrape frequency

**For your current setup (3 nodes): 4 CPU, 8 GB RAM, 100 GB disk is ideal**

### Supported Operating Systems

- RHEL/CentOS 7.x, 8.x
- Rocky Linux 8.x, 9.x
- Ubuntu 18.04, 20.04, 22.04, 24.04
- Debian 10, 11

### Network Requirements

- All nodes must have internet connectivity to download RKE2
- Nodes must be able to communicate with each other
- Load Balancer for RKE2 API Server (recommended for production)

### Required Ports

**Master Nodes:**

- 9345/tcp - RKE2 supervisor API
- 6443/tcp - Kubernetes API
- 10250/tcp - Kubelet metrics
- 2379-2380/tcp - etcd
- 8472/udp - VXLAN (Canal/Flannel)
- 4789/udp - VXLAN (Flannel)
- 9098/tcp - Canal (Calico health check)
- 9099/tcp - Canal (Felix health check)

**Worker Nodes:**

- 10250/tcp - Kubelet metrics
- 8472/udp - VXLAN (Canal/Flannel)
- 4789/udp - VXLAN (Flannel)

**All Nodes:**

- 30000-32767/tcp - NodePort Services

**Monitoring Node:**

- 9090/tcp - Prometheus UI and API
- 3000/tcp - Grafana UI
- 9100/tcp - Node Exporter metrics
- 9093/tcp - AlertManager (optional)

## Installing Ansible

### macOS

```bash
brew install ansible
```

### Ubuntu/Debian

```bash
sudo apt update
sudo apt install ansible -y
```

### RHEL/CentOS

```bash
sudo yum install ansible -y
# or
sudo dnf install ansible -y
```

### Install Required Ansible Collections

```bash
ansible-galaxy collection install ansible.posix
ansible-galaxy collection install community.general
```

## 📋 Configuration

### 1. Configure Environment Variables (.env)

```bash
# Copy example file
cp .env.example .env

# Edit important variables
vim .env
```

**Key variables to configure:**

```bash
# API Server Load Balancer VIP or DNS
RKE2_API_IP="192.168.1.100"

# Cluster token - MUST CHANGE THIS
# Note: Use a simple password string, not K10<hash>::<user>:<pass> format
RKE2_TOKEN="your-secure-random-token-here"

# Network Plugin
RKE2_CNI="canal"  # canal, calico, cilium, flannel

# CIDR Ranges
RKE2_CLUSTER_CIDR="10.42.0.0/16"
RKE2_SERVICE_CIDR="10.43.0.0/16"

# Additional TLS SANs (comma-separated)
RKE2_TLS_SAN_EXTRA="rke2.example.com,kubernetes.example.com"

# Container Registry Configuration (JSON format for multiple registries)
REGISTRIES_JSON='[{"url":"registry.company.com","username":"admin","password":"secret"}]'
```

### 2. Configure Inventory (hosts.yml)

```bash
# Copy example file
cp inventory/hosts.yml.example inventory/hosts.yml

# Edit with your node information
vim inventory/hosts.yml
```

**Example configuration:**

```yaml
all:
  children:
    master:
      hosts:
        k8s-master-01:
          ansible_host: 192.168.1.101
          ansible_user: root
          ansible_ssh_private_key_file: ~/.ssh/id_rsa
    worker:
      hosts:
        k8s-worker-01:
          ansible_host: 192.168.1.111
          ansible_user: root
          ansible_ssh_private_key_file: ~/.ssh/id_rsa
        k8s-worker-02:
          ansible_host: 192.168.1.112
          ansible_user: root
          ansible_ssh_private_key_file: ~/.ssh/id_rsa
```

**SSH Options:**

```yaml
# Option 1: SSH Key (Recommended)
ansible_ssh_private_key_file: ~/.ssh/id_rsa

# Option 2: Password
ansible_ssh_pass: your_password

# Option 3: Sudo password (if non-root user)
ansible_become_pass: your_sudo_password
```

### 3. Setup SSH Key-based Authentication (Recommended)

```bash
# Generate SSH key if not exists
ssh-keygen -t rsa -b 4096

# Copy SSH key to all nodes
ssh-copy-id root@192.168.1.101
ssh-copy-id root@192.168.1.111
ssh-copy-id root@192.168.1.112

# Test SSH connectivity
ssh root@192.168.1.101
```

### 4. Test Ansible Connectivity

```bash
# Load environment variables
set -a && source .env && set +a

# Test with SSH key
ansible -i inventory/hosts.yml all -m ping

# Or test with password
ansible -i inventory/hosts.yml all -m ping --ask-pass
```

## 🔧 Installing RKE2 Cluster

### 1. Verify Configuration

```bash
# Check syntax
ansible-playbook -i inventory/hosts.yml site.yml --syntax-check

# Dry run (no changes made)
ansible-playbook -i inventory/hosts.yml site.yml --check

# List tasks to be executed
ansible-playbook -i inventory/hosts.yml site.yml --list-tasks
```

### 2. Run Installation

```bash
# Load environment variables first
set -a && source .env && set +a

# Full cluster installation
ansible-playbook -i inventory/hosts.yml site.yml

# With verbose output (for debugging)
ansible-playbook -i inventory/hosts.yml site.yml -v
# or -vv, -vvv, -vvvv for more details
```

### 3. Install Specific Components

```bash
# Install master nodes only
ansible-playbook -i inventory/hosts.yml site.yml --limit master

# Install worker nodes only
ansible-playbook -i inventory/hosts.yml site.yml --limit worker

# Install specific node only
ansible-playbook -i inventory/hosts.yml site.yml --limit k8s-master-01
```

## 📊 Cluster Management

### Check Cluster Status

```bash
# SSH to master node
ssh root@<master-ip>

# Check cluster nodes
kubectl get nodes -o wide

# Check all pods across namespaces
kubectl get pods -A -o wide

# Check RKE2 service status
systemctl status rke2-server  # on master
systemctl status rke2-agent   # on worker
```

### Verify Installation

Check cluster status:

```bash
# Check nodes
kubectl get nodes -o wide

# Check system pods
kubectl get pods -A

# Check RKE2 version
kubectl version
```

## Load Balancer Setup (Important for HA)

For production HA setup, configure a Load Balancer for RKE2 API server:

### HAProxy Configuration

```bash
# /etc/haproxy/haproxy.cfg
frontend rke2_api_frontend
    bind *:6443
    mode tcp
    option tcplog
    default_backend rke2_api_backend

frontend rke2_supervisor_frontend
    bind *:9345
    mode tcp
    option tcplog
    default_backend rke2_supervisor_backend

backend rke2_api_backend
    mode tcp
    option tcp-check
    balance roundrobin
    server master-01 192.168.1.101:6443 check
    server master-02 192.168.1.102:6443 check
    server master-03 192.168.1.103:6443 check

backend rke2_supervisor_backend
    mode tcp
    option tcp-check
    balance roundrobin
    server master-01 192.168.1.101:9345 check
    server master-02 192.168.1.102:9345 check
    server master-03 192.168.1.103:9345 check
```

### Nginx Load Balancer (Alternative)

```nginx
# /etc/nginx/nginx.conf
stream {
    upstream rke2_api {
        least_conn;
        server 192.168.1.101:6443 max_fails=3 fail_timeout=5s;
        server 192.168.1.102:6443 max_fails=3 fail_timeout=5s;
        server 192.168.1.103:6443 max_fails=3 fail_timeout=5s;
    }

    upstream rke2_supervisor {
        least_conn;
        server 192.168.1.101:9345 max_fails=3 fail_timeout=5s;
        server 192.168.1.102:9345 max_fails=3 fail_timeout=5s;
        server 192.168.1.103:9345 max_fails=3 fail_timeout=5s;
    }

    server {
        listen 6443;
        proxy_pass rke2_api;
    }

    server {
        listen 9345;
        proxy_pass rke2_supervisor;
    }
}
```

## 🎯 Using the Cluster

### 1. Get kubeconfig

```bash
# Copy from master node
scp root@192.168.1.101:/etc/rancher/rke2/rke2.yaml ~/.kube/rke2-config

# Update server address in kubeconfig (replace 127.0.0.1 with Load Balancer IP)
sed -i '' 's/127.0.0.1/192.168.1.100/g' ~/.kube/rke2-config

# Export kubeconfig
export KUBECONFIG=~/.kube/rke2-config

# Or merge into main kubeconfig
KUBECONFIG=~/.kube/config:~/.kube/rke2-config kubectl config view --flatten > ~/.kube/config.new
mv ~/.kube/config.new ~/.kube/config
```

### 2. Verify Cluster

```bash
# Check nodes
kubectl get nodes -o wide

# Check system pods
kubectl get pods -A

# Cluster info
kubectl cluster-info

# Check RKE2 version
kubectl get nodes -o jsonpath='{.items[0].status.nodeInfo.kubeletVersion}'

# Check etcd health
kubectl get pods -n kube-system -l component=etcd

# View component status
kubectl get componentstatuses  # deprecated in newer versions
kubectl get --raw='/readyz?verbose'  # preferred method
```

### 3. Deploy Test Application

```bash
# Create test deployment
kubectl create deployment nginx --image=nginx --replicas=3

# Expose as service
kubectl expose deployment nginx --port=80 --type=NodePort

# Check deployment
kubectl get deployments
kubectl get pods -l app=nginx
kubectl get svc nginx

# Access the service
curl http://<node-ip>:<node-port>

# Cleanup
kubectl delete deployment nginx
kubectl delete service nginx
```

## 📝 Cluster Management

### Add New Worker Node

1. Add node to `inventory/hosts.yml`:

```yaml
worker:
  hosts:
    k8s-worker-03:
      ansible_host: 192.168.1.113
      ansible_user: root
      ansible_ssh_private_key_file: ~/.ssh/id_rsa
```

1. Run playbook for new node only:

```bash
set -a && source .env && set +a
ansible-playbook -i inventory/hosts.yml site.yml --limit k8s-worker-03
```

1. Verify node joined:

```bash
kubectl get nodes
```

### Add New Master Node

1. Add to inventory under `master` section
2. Update Load Balancer configuration to include new master
3. Run playbook:

```bash
set -a && source .env && set +a
ansible-playbook -i inventory/hosts.yml site.yml --limit k8s-master-02
```

1. Verify etcd cluster:

```bash
kubectl get pods -n kube-system -l component=etcd
```

### Remove Node

```bash
# Drain node first
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# Remove from cluster
kubectl delete node <node-name>

# Uninstall RKE2 on the node
ansible-playbook -i inventory/hosts.yml uninstall.yml --limit <node-name>

# Remove from inventory
# Edit inventory/hosts.yml and remove the node entry
```

## � Monitoring Stack

### Overview

Deploy a complete monitoring stack with Prometheus, Grafana, and Node Exporter to monitor your RKE2 Kubernetes cluster.

### Architecture

- **Monitoring Server**: Standalone VM running Prometheus + Grafana
- **Node Exporter**: Deployed on all Kubernetes nodes (masters + workers)
- **Metrics Collection**: Prometheus scrapes metrics from Kubernetes API, Kubelet, cAdvisor, and Node Exporters

### Prerequisites

1. **A dedicated VM for monitoring**
   - Minimum: 2 CPU, 4GB RAM, 50GB disk (testing only)
   - **Recommended for 3 nodes: 4 CPU, 8GB RAM, 100GB disk**
   - See detailed sizing guide: [docs/monitoring-sizing-guide.md](docs/monitoring-sizing-guide.md)
2. SSH access from Ansible control node to monitoring VM
3. Network connectivity from monitoring VM to all Kubernetes nodes
4. Open ports: 9090 (Prometheus), 3000 (Grafana), 9100 (Node Exporter)

### 1. Configure Monitoring VM

Add monitoring node to inventory:

```bash
vim inventory/hosts.yml
```

```yaml
all:
  children:
    master:
      hosts:
        k8s-master-01:
          ansible_host: 172.23.202.14
          # ...
    
    worker:
      hosts:
        k8s-worker-01:
          ansible_host: 172.23.202.15
          # ...
    
    monitoring:
      hosts:
        k8s-monitor-01:
          ansible_host: 172.23.202.17  # Update with your monitoring VM IP
          ansible_user: root
          ansible_ssh_private_key_file: ~/.ssh/fci
```

### 2. Deploy Monitoring Stack

```bash
# Load environment variables
set -a && source .env && set +a

# Deploy monitoring stack
ansible-playbook -i inventory/hosts.yml monitoring.yml

# Installation includes:
# - Prometheus 2.48.1
# - Grafana 10.2.3
# - Node Exporter 1.7.0 (on all nodes)
```

### 3. Access Monitoring Services

After deployment:

- **Prometheus**: `http://<monitoring-vm-ip>:9090`
- **Grafana**: `http://<monitoring-vm-ip>:3000`
  - Default login: `admin` / `admin` (change on first login)

### 4. Configure Grafana

1. **Add Prometheus Data Source:**
   - Navigate to Configuration → Data Sources
   - Click "Add data source"
   - Select "Prometheus"
   - URL: `http://localhost:9090`
   - Click "Save & Test"

2. **Import Kubernetes Dashboards:**
   - Go to Dashboards → Import
   - Import popular dashboards by ID:
     - **315**: Kubernetes cluster monitoring
     - **6417**: Kubernetes cluster (Prometheus)
     - **12740**: Kubernetes monitoring
     - **1860**: Node Exporter Full
     - **3119**: Kubernetes Cluster (Prometheus)
     - **747**: Kubernetes deployment statefulset daemonset metrics

### Monitored Metrics

The monitoring stack collects:

- **Kubernetes API Server**: API request rates, latency, errors
- **Kubelet**: Container and pod metrics from all nodes
- **cAdvisor**: Container resource usage (CPU, memory, network, disk)
- **Node Exporter**: System metrics (CPU, memory, disk, network) from all nodes
- **etcd**: Cluster health and performance (from master nodes)

### Prometheus Configuration

Prometheus is configured to scrape:

- Prometheus itself (localhost:9090)
- Node Exporter on monitoring server
- Node Exporters on all Kubernetes nodes
- Kubernetes API servers (all masters)
- Kubelet metrics (all nodes)
- cAdvisor metrics (all nodes)

Configuration file: `/etc/prometheus/prometheus.yml`

### Node Exporter Metrics

Access Node Exporter metrics:

- Monitoring server: `http://<monitoring-ip>:9100/metrics`
- Master nodes: `http://<master-ip>:9100/metrics`
- Worker nodes: `http://<worker-ip>:9100/metrics`

### Troubleshooting Monitoring

```bash
# Check Prometheus status
ssh root@<monitoring-ip>
systemctl status prometheus
journalctl -u prometheus -f

# Check Grafana status
systemctl status grafana-server
journalctl -u grafana-server -f

# Check Node Exporter on nodes
ansible -i inventory/hosts.yml rke2_cluster -m shell -a "systemctl status node_exporter"

# Test Prometheus targets
curl http://<monitoring-ip>:9090/api/v1/targets

# Test metric collection
curl http://<monitoring-ip>:9090/api/v1/query?query=up
```

### Alerting (Optional)

To configure alerting with Alertmanager:

1. Install Alertmanager on monitoring server
2. Create alert rules in `/etc/prometheus/rules/`
3. Configure alertmanager in `/etc/prometheus/prometheus.yml`
4. Set up notification channels (email, Slack, etc.)

### Backup Monitoring Data

```bash
# Prometheus data (TSDB)
tar -czf prometheus-backup-$(date +%Y%m%d).tar.gz /var/lib/prometheus/

# Grafana dashboards and config
tar -czf grafana-backup-$(date +%Y%m%d).tar.gz /etc/grafana/ /var/lib/grafana/
```

### Monitoring Best Practices

1. Set up alerting for critical metrics (node down, high CPU/memory)
2. Retain Prometheus data for at least 30 days (configured: 30d)
3. Regularly backup Grafana dashboards
4. Monitor monitoring server resources
5. Use long-term storage (e.g., Thanos, Cortex) for data retention > 30 days
6. Create custom dashboards for application-specific metrics
7. Set up authentication for Prometheus UI in production

## 📂 Project Structure

```
kubernetes-cookbook/
├── .env.example              # Environment variables template
├── .env                      # Actual configuration (gitignored)
├── .gitignore               # Git ignore rules
├── ansible.cfg              # Ansible configuration
├── site.yml                 # Main installation playbook
├── monitoring.yml           # Monitoring stack deployment playbook
├── uninstall.yml            # Uninstall playbook
├── README.md                # This file
├── inventory/
│   ├── hosts.yml.example    # Inventory template
│   └── hosts.yml           # Actual inventory (gitignored)
├── group_vars/
│   └── all.yml             # Ansible variables (reads from environment)
├── vars/
│   └── registry.yml        # Complex variable parsing (registries, taints)
└── roles/
    ├── prereq/             # System preparation
    │   └── tasks/
    │       └── main.yml
    ├── rke2-server/        # RKE2 master nodes installation
    │   ├── tasks/
    │   │   ├── main.yml
    │   │   └── registry.yml
    │   └── templates/
    │       ├── config.yaml.j2
    │       └── registries.yaml.j2
    ├── rke2-agent/         # RKE2 worker nodes installation
    │   ├── tasks/
    │   │   ├── main.yml
    │   │   └── registry.yml
    │   └── templates/
    │       ├── config.yaml.j2
    │       └── registries.yaml.j2
    ├── monitoring/         # Monitoring stack (Prometheus + Grafana)
    │   ├── defaults/
    │   │   └── main.yml
    │   ├── tasks/
    │   │   ├── main.yml
    │   │   ├── prerequisites.yml
    │   │   ├── prometheus.yml
    │   │   ├── grafana.yml
    │   │   └── node_exporter.yml
    │   ├── templates/
    │   │   ├── prometheus.yml.j2
    │   │   ├── prometheus.service.j2
    │   │   ├── grafana.ini.j2
    │   │   ├── grafana.service.j2
    │   │   └── node_exporter.service.j2
    │   └── handlers/
    │       └── main.yml
    └── node-exporter/      # Node Exporter for cluster nodes
        └── tasks/
            └── main.yml
```

## 🐛 Troubleshooting

### 1. Check RKE2 Service Status

```bash
# From Ansible control node
ansible -i inventory/hosts.yml master -m shell -a "systemctl status rke2-server"
ansible -i inventory/hosts.yml worker -m shell -a "systemctl status rke2-agent"

# View logs
ansible -i inventory/hosts.yml master -m shell -a "journalctl -u rke2-server -n 50"
ansible -i inventory/hosts.yml worker -m shell -a "journalctl -u rke2-agent -n 50"

# Or SSH directly to node
ssh root@192.168.1.101
systemctl status rke2-server
journalctl -u rke2-server -f
```

### 2. Node Not Ready

```bash
# Check node conditions
kubectl describe node <node-name>

# Check kubelet logs on worker
ssh root@<worker-ip>
journalctl -u rke2-agent -n 100 --no-pager

# Check CNI pods
kubectl get pods -n kube-system -o wide | grep -E 'canal|calico|cilium'

# Restart RKE2 service
systemctl restart rke2-agent  # on worker
systemctl restart rke2-server # on master
```

### 3. etcd Issues

```bash
# Check etcd pods
kubectl get pods -n kube-system -l component=etcd

# Check etcd health (from master node)
ETCDCTL_API=3 /var/lib/rancher/rke2/bin/etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/var/lib/rancher/rke2/server/tls/etcd/server-ca.crt \
  --cert=/var/lib/rancher/rke2/server/tls/etcd/server-client.crt \
  --key=/var/lib/rancher/rke2/server/tls/etcd/server-client.key \
  endpoint health

# List etcd members
ETCDCTL_API=3 /var/lib/rancher/rke2/bin/etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/var/lib/rancher/rke2/server/tls/etcd/server-ca.crt \
  --cert=/var/lib/rancher/rke2/server/tls/etcd/server-client.crt \
  --key=/var/lib/rancher/rke2/server/tls/etcd/server-client.key \
  member list
```

### 4. Certificate Issues

```bash
# Check certificate validity
openssl x509 -in /var/lib/rancher/rke2/server/tls/server-ca.crt -text -noout | grep -A2 Validity

# Verify TLS connection
openssl s_client -connect <master-ip>:6443 -servername kubernetes

# Check kubelet certificates
ls -la /var/lib/rancher/rke2/agent/*.crt
```

### 5. Network Issues

```bash
# Test connectivity between nodes
ansible -i inventory/hosts.yml all -m ping

# Test port connectivity
ansible -i inventory/hosts.yml all -m wait_for -a "host=192.168.1.101 port=6443 timeout=5"

# Check iptables rules
ansible -i inventory/hosts.yml all -m shell -a "iptables -L -n | grep 10.42"

# Test RKE2 API endpoint
curl -k https://192.168.1.100:6443/version

# Check pod network connectivity
kubectl run test-pod --image=busybox --rm -it -- ping 10.42.0.1
```

### 6. SSH Issues

```bash
# Test SSH connectivity with verbose output
ssh -vvv root@192.168.1.101

# Copy SSH key again if needed
ssh-copy-id -i ~/.ssh/id_rsa.pub root@192.168.1.101

# Test with password authentication
ansible -i inventory/hosts.yml all -m ping --ask-pass

# Check SSH configuration
cat ~/.ssh/config
```

### 7. Ansible Issues

```bash
# Verbose mode to see detailed errors
ansible-playbook -i inventory/hosts.yml site.yml -vvv

# Check inventory parsing
ansible-inventory -i inventory/hosts.yml --list
ansible-inventory -i inventory/hosts.yml --graph

# Test fact gathering
ansible -i inventory/hosts.yml all -m setup

# Validate environment variables
set -a && source .env && set +a
env | grep RKE2

# Test RKE2 API
curl -k https://<master-ip>:6443
```

### 8. Registry Issues

```bash
# Check registry configuration
cat /etc/rancher/rke2/registries.yaml

# Test registry connectivity
curl -v https://btxh-reg.azinsu.com/v2/_catalog

# Check pod image pull status
kubectl describe pod <pod-name> | grep -A5 Events

# View containerd logs
journalctl -u containerd -n 100 --no-pager
```

## 🔄 Upgrade RKE2

### Method 1: Using Ansible

1. Update `RKE2_VERSION` in `.env`:

```bash
RKE2_VERSION="v1.35.0+rke2r1"
```

1. Load environment and run playbook:

```bash
set -a && source .env && set +a
ansible-playbook -i inventory/hosts.yml site.yml
```

### Method 2: Manual Upgrade

```bash
# On each node, run:
curl -sfL https://get.rke2.io | INSTALL_RKE2_VERSION=v1.35.0+rke2r1 sh -

# Restart service
systemctl restart rke2-server  # on master
systemctl restart rke2-agent   # on worker

# Verify upgrade
kubectl get nodes
```

**Note:** Always upgrade master nodes first, then worker nodes.

## 💾 Backup and Restore

### Backup etcd

```bash
# SSH to master node
ssh root@<master-ip>

# Create etcd snapshot using RKE2 built-in command
rke2 etcd-snapshot save --name snapshot-$(date +%Y%m%d-%H%M%S)

# List snapshots
rke2 etcd-snapshot list

# Snapshots are stored in: /var/lib/rancher/rke2/server/db/snapshots/

# Copy snapshot to backup location
scp /var/lib/rancher/rke2/server/db/snapshots/snapshot-*.db backup-server:/backups/
```

### Restore from Backup

```bash
# Stop RKE2 on all master nodes
systemctl stop rke2-server

# On first master node, restore snapshot
rke2 server \
  --cluster-reset \
  --cluster-reset-restore-path=/var/lib/rancher/rke2/server/db/snapshots/snapshot-xxx.db

# Start RKE2 on first master
systemctl start rke2-server

# Wait for cluster to be ready
kubectl get nodes

# Re-join other master nodes (if multi-master setup)
# They will automatically sync from the first master
systemctl start rke2-server
```

## ✨ Best Practices

1. **Use at least 3 master nodes** for production HA setup
2. **Setup Load Balancer** before cluster installation
3. **Backup etcd regularly** (recommended: daily automated backups)
4. **Monitor cluster health** with Prometheus/Grafana
5. **Update RKE2 regularly** to patch security vulnerabilities
6. **Use persistent storage** for production workloads
7. **Configure resource limits** for pods (requests/limits)
8. **Implement network policies** for security isolation
9. **Enable audit logging** to track cluster activities
10. **Test disaster recovery** procedures periodically
11. **Use private registries** with authentication for production images
12. **Implement proper RBAC** for user access control
13. **Enable Pod Security Standards** (PSS) for workload security
14. **Use secrets management** (e.g., Sealed Secrets, External Secrets)
15. **Regular security scanning** of container images

## 🗑️ Uninstall Cluster

To completely remove RKE2 from all nodes:

```bash
set -a && source .env && set +a
ansible-playbook -i inventory/hosts.yml uninstall.yml
```

This will:

- Stop RKE2 services on all nodes
- Remove RKE2 binaries and configuration files
- Clean up container images and volumes
- Reset network interfaces
- Remove firewall rules

## 📚 References

- [RKE2 Official Documentation](https://docs.rke2.io/)
- [RKE2 GitHub Repository](https://github.com/rancher/rke2)
- [RKE2 Installation Options](https://docs.rke2.io/install/install_options/install_options/)
- [RKE2 HA Setup Guide](https://docs.rke2.io/install/ha)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Ansible Documentation](https://docs.ansible.com/)
- [Canal CNI Documentation](https://projectcalico.docs.tigera.io/getting-started/kubernetes/flannel/flannel)

## 📝 License

This project is licensed under the MIT License.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 💬 Support

If you encounter any issues or have questions:

1. Check the Troubleshooting section above
2. Review RKE2 official documentation
3. Open an issue in this repository

---

**Author:** XDEV Asia Labs  
**Last Updated:** December 2025  
**RKE2 Version:** v1.34.2+rke2r1 (Kubernetes v1.34.2)

## License

MIT License

## Đóng góp

Mọi đóng góp đều được chào đón! Vui lòng tạo pull request hoặc issue.

## Support

Nếu gặp vấn đề, vui lòng:

1. Kiểm tra phần Troubleshooting
2. Xem RKE2 logs: `journalctl -u rke2-server -f`
3. Tạo issue với đầy đủ thông tin về lỗi
