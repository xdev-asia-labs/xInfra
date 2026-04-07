# Quick Start Guide

## 🚀 5-Minute Setup

### Step 1: Clone Repository

```bash
git clone <repository-url>
cd kvm-cockpit-vxlan-cookbook
```

### Step 2: Configure .env

```bash
# Copy example file
cp .env.example .env

# Edit with your information
vim .env
```

Update these values in `.env`:

```bash
# Node IPs - IMPORTANT!
NODE1_IP=192.168.1.10    # Node 1 IP address
NODE2_IP=192.168.1.11    # Node 2 IP address

# Node Users
NODE1_USER=ubuntu        # SSH username
NODE2_USER=ubuntu

# Network
NETWORK_GATEWAY=192.168.1.1
PRIMARY_INTERFACE=enp0s3  # Check with: ip link
```

### Step 3: Setup SSH Keys (Recommended)

#### Automated (Recommended)

```bash
# Automated script to create and copy SSH keys
./scripts/setup-ssh-keys.sh
```

The script will:

- ✅ Create new SSH key (if not exists)
- ✅ Copy key to both nodes
- ✅ Test connections
- ✅ Auto-update .env file
- ✅ Add to ~/.ssh/config (optional)

#### Manual Setup

```bash
# 1. Create SSH key
ssh-keygen -t ed25519 -f ~/.ssh/kvm_infrastructure_ed25519 -C "ansible@kvm"

# 2. Copy key to nodes
ssh-copy-id -i ~/.ssh/kvm_infrastructure_ed25519.pub ubuntu@192.168.1.10
ssh-copy-id -i ~/.ssh/kvm_infrastructure_ed25519.pub ubuntu@192.168.1.11

# 3. Test SSH
ssh -i ~/.ssh/kvm_infrastructure_ed25519 ubuntu@192.168.1.10 "echo OK"
ssh -i ~/.ssh/kvm_infrastructure_ed25519 ubuntu@192.168.1.11 "echo OK"

# 4. Add to .env
echo "SSH_KEY_PATH=~/.ssh/kvm_infrastructure_ed25519" >> .env
```

📖 **Detailed guide**: [SSH_KEYS_GUIDE.md](SSH_KEYS_GUIDE.md)

### Step 4: Generate Config and Test

```bash
# Generate inventory from .env
./scripts/generate_inventory.sh

# Test Ansible connection
ansible all -m ping
```

If successful, you'll see:

```
kvm-node01 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
kvm-node02 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

### Step 5: Run Playbook

```bash
# Full installation
ansible-playbook site.yml

# Or step by step
ansible-playbook site.yml --tags kvm
ansible-playbook site.yml --tags network
ansible-playbook site.yml --tags cockpit
```

### Step 6: Access Cockpit Web UI

Open browser:

- Node 1: <https://192.168.1.10:9090>
- Node 2: <https://192.168.1.11:9090>

Login with your Linux user credentials.

---

## 🔐 Security Checklist

- [ ] `.env` file created and configured
- [ ] **DO NOT** commit `.env` file to git
- [ ] **DO NOT** commit `inventory.yml` to git
- [ ] **DO NOT** commit `group_vars/all.yml` to git
- [ ] SSH keys setup instead of passwords
- [ ] Use Ansible Vault for passwords (if needed)

---

## 📝 Minimum .env Template

```bash
# Minimum required configuration
NODE1_NAME=kvm-node01
NODE1_IP=192.168.1.10
NODE1_USER=ubuntu

NODE2_NAME=kvm-node02
NODE2_IP=192.168.1.11
NODE2_USER=ubuntu

NETWORK_GATEWAY=192.168.1.1
PRIMARY_INTERFACE=enp0s3
```

Other values will use defaults if not specified.

---

## ⚡ Common Commands

```bash
# Re-generate config after changing .env
./scripts/generate_inventory.sh

# Run full playbook
ansible-playbook site.yml

# Run with verbose output
ansible-playbook site.yml -v

# Install KVM only
ansible-playbook site.yml --tags kvm

# Configure network only
ansible-playbook site.yml --tags network,vxlan

# Run on specific node
ansible-playbook site.yml --limit kvm-node01

# Check mode (dry run)
ansible-playbook site.yml --check

# List tasks
ansible-playbook site.yml --list-tasks

# List hosts
ansible-playbook site.yml --list-hosts
```

---

## 🐛 Quick Troubleshooting

### Error: "Could not match supplied host pattern"

```bash
# Check inventory
cat inventory.yml

# Re-generate
./scripts/generate_inventory.sh
```

### Error: "Permission denied (publickey,password)"

```bash
# Run SSH keys setup script
./scripts/setup-ssh-keys.sh

# Or manually:
# 1. Create key
ssh-keygen -t ed25519 -f ~/.ssh/kvm_infrastructure_ed25519

# 2. Copy to nodes
ssh-copy-id -i ~/.ssh/kvm_infrastructure_ed25519.pub ubuntu@192.168.1.10
ssh-copy-id -i ~/.ssh/kvm_infrastructure_ed25519.pub ubuntu@192.168.1.11

# 3. Test SSH
ssh -i ~/.ssh/kvm_infrastructure_ed25519 ubuntu@192.168.1.10 "echo OK"

# 4. Update .env
echo "SSH_KEY_PATH=~/.ssh/kvm_infrastructure_ed25519" >> .env

# 5. Re-generate inventory
./scripts/generate_inventory.sh
```

### Error: Network interface not found

```bash
# Check interface name on target nodes
ssh ubuntu@192.168.1.10 "ip link"

# Update in .env
vim .env
# PRIMARY_INTERFACE=ens18  # or your interface name

# Re-generate
./scripts/generate_inventory.sh
```

---

## 📚 Further Reading

- [README.md](README.md) - Complete documentation
- [SECURITY.md](SECURITY.md) - Security best practices
- [EXAMPLES.md](EXAMPLES.md) - VM creation and management examples
