# SSH Keys Setup Guide

## 📖 Overview

SSH keys are the most secure authentication method for Ansible to connect to nodes. Instead of using a password each time, SSH keys use cryptography for automatic authentication.

## 🎯 Why Use SSH Keys?

| Method | Security | Automation | Recommendation |
|--------|----------|------------|----------------|
| Password | ⚠️ Low | ❌ No | ❌ Not recommended |
| SSH Key | ✅ High | ✅ Yes | ✅ **Recommended** |
| SSH + Vault | 🔒 Very high | ✅ Yes | ✅ Production |

**Benefits:**

- 🔐 Higher security than passwords
- 🚀 Automatic, no password entry needed
- 🔑 Easy to manage and rotate
- 📝 Better audit trail
- 🛡️ Protection against brute-force attacks

## 🚀 Quick Start

### Method 1: Automated Script (Recommended)

```bash
# Run script once
./scripts/setup-ssh-keys.sh
```

**Script will automatically:**

1. ✅ Create SSH key pair (ed25519)
2. ✅ Copy public key to all nodes
3. ✅ Test connection
4. ✅ Update .env with SSH_KEY_PATH
5. ✅ Add to ~/.ssh/config (optional)

### Method 2: Manual Setup

See [Manual Setup](#-manual-setup-details) section below.

## 🔧 Manual Setup Details

### Step 1: Create SSH Key Pair

```bash
# ED25519 (recommended - nhanh, nhỏ, bảo mật cao)
ssh-keygen -t ed25519 \
  -f ~/.ssh/kvm_infrastructure_ed25519 \
  -C "ansible@kvm-infrastructure"

# RSA (if old systems don't support ed25519)
ssh-keygen -t rsa -b 4096 \
  -f ~/.ssh/kvm_infrastructure_rsa \
  -C "ansible@kvm-infrastructure"
```

**Options:**

- `-t ed25519`: Algorithm (ed25519 or rsa)
- `-f`: File path for key
- `-C`: Comment to identify key
- `-N ""`: No passphrase (optional, for automation)

**Recommended**: Use passphrase and ssh-agent for better security:

```bash
# Create key with passphrase
ssh-keygen -t ed25519 -f ~/.ssh/kvm_infrastructure_ed25519

# Add to ssh-agent
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/kvm_infrastructure_ed25519
```

### Step 2: Set Permissions

```bash
# Private key must be readable only by owner
chmod 600 ~/.ssh/kvm_infrastructure_ed25519

# Public key can be readable
chmod 644 ~/.ssh/kvm_infrastructure_ed25519.pub

# .ssh directory
chmod 700 ~/.ssh
```

### Step 3: Copy Public Key to Nodes

#### Method A: Using ssh-copy-id (Recommended)

```bash
# Node 1
ssh-copy-id -i ~/.ssh/kvm_infrastructure_ed25519.pub ubuntu@192.168.1.10

# Node 2
ssh-copy-id -i ~/.ssh/kvm_infrastructure_ed25519.pub ubuntu@192.168.1.11
```

#### Method B: Manual Copy

```bash
# View public key
cat ~/.ssh/kvm_infrastructure_ed25519.pub

# Copy and paste to node
ssh ubuntu@192.168.1.10
mkdir -p ~/.ssh
echo "ssh-ed25519 AAAA... ansible@kvm-infrastructure" >> ~/.ssh/authorized_keys
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
exit
```

#### Method C: Ansible Ad-hoc (If you already have password access)

```bash
# Sử dụng Ansible để copy key
ansible all -i "192.168.1.10,192.168.1.11," \
  -u ubuntu --ask-pass \
  -m authorized_key \
  -a "user=ubuntu state=present key={{ lookup('file', '~/.ssh/kvm_infrastructure_ed25519.pub') }}"
```

### Step 4: Test SSH Connection

```bash
# Test with key
ssh -i ~/.ssh/kvm_infrastructure_ed25519 ubuntu@192.168.1.10 "hostname; uptime"

# Test with verbose for debugging
ssh -vvv -i ~/.ssh/kvm_infrastructure_ed25519 ubuntu@192.168.1.10
```

**Expected output:**

```
kvm-node01
 10:30:01 up 1 day,  2:30,  1 user,  load average: 0.00, 0.01, 0.05
```

### Step 5: Configure SSH Config

Create or edit `~/.ssh/config`:

```bash
# Backup existing config
cp ~/.ssh/config ~/.ssh/config.backup 2>/dev/null || true

# Thêm configuration
cat >> ~/.ssh/config <<'EOF'

# KVM Infrastructure Nodes
Host kvm-node01 192.168.1.10 node01
    HostName 192.168.1.10
    User ubuntu
    IdentityFile ~/.ssh/kvm_infrastructure_ed25519
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    LogLevel ERROR
    
Host kvm-node02 192.168.1.11 node02
    HostName 192.168.1.11
    User ubuntu
    IdentityFile ~/.ssh/kvm_infrastructure_ed25519
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    LogLevel ERROR

# Wildcard for all kvm nodes
Host kvm-node*
    User ubuntu
    IdentityFile ~/.ssh/kvm_infrastructure_ed25519
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    ServerAliveInterval 60
    ServerAliveCountMax 3
    Compression yes
EOF

chmod 600 ~/.ssh/config
```

**SSH Config Options explained:**

- `HostName`: IP thực của node
- `User`: Username SSH
- `IdentityFile`: Path tới private key
- `StrictHostKeyChecking no`: Auto accept host key (dev only)
- `UserKnownHostsFile /dev/null`: Don't save host keys (dev only)
- `ServerAliveInterval`: Keep connection alive
- `Compression yes`: Enable compression

**Lưu ý**: Trong production, nên bật `StrictHostKeyChecking yes`.

### Step 6: Update .env

```bash
# Thêm SSH key path vào .env
cat >> .env <<EOF

# SSH Configuration
SSH_KEY_PATH=~/.ssh/kvm_infrastructure_ed25519
EOF
```

### Step 7: Update Inventory

Inventory sẽ tự động sử dụng SSH key từ .env khi bạn chạy:

```bash
./scripts/generate_inventory.sh
```

Hoặc thêm thủ công vào `inventory.yml`:

```yaml
all:
  children:
    kvm_hosts:
      vars:
        ansible_user: ubuntu
        ansible_ssh_private_key_file: ~/.ssh/kvm_infrastructure_ed25519
        ansible_become: yes
```

### Step 8: Test Ansible Connection

```bash
# Test ping
ansible all -m ping

# Test command
ansible all -m command -a "hostname"

# Test with verbose
ansible all -m ping -vvv
```

**Expected output:**

```yaml
kvm-node01 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
kvm-node02 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

## 🔒 Security Best Practices

### 1. Sử dụng Passphrase cho Private Key

```bash
# Create key with passphrase
ssh-keygen -t ed25519 -f ~/.ssh/kvm_infrastructure_ed25519

# Sử dụng ssh-agent để không nhập passphrase mỗi lần
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/kvm_infrastructure_ed25519

# Check keys trong agent
ssh-add -l
```

### 2. Key Rotation

Rotate keys định kỳ (mỗi 6-12 tháng):

```bash
# 1. Create new key
ssh-keygen -t ed25519 -f ~/.ssh/kvm_infrastructure_ed25519_new

# 2. Copy key mới sang nodes
ssh-copy-id -i ~/.ssh/kvm_infrastructure_ed25519_new.pub ubuntu@192.168.1.10
ssh-copy-id -i ~/.ssh/kvm_infrastructure_ed25519_new.pub ubuntu@192.168.1.11

# 3. Test key mới
ssh -i ~/.ssh/kvm_infrastructure_ed25519_new ubuntu@192.168.1.10

# 4. Update .env
sed -i 's/kvm_infrastructure_ed25519/kvm_infrastructure_ed25519_new/g' .env

# 5. Remove old key from nodes
ssh ubuntu@192.168.1.10 "sed -i '/old-key-fingerprint/d' ~/.ssh/authorized_keys"
```

### 3. Restrict Key Usage trên Target Nodes

Edit `~/.ssh/authorized_keys` trên nodes:

```bash
# Chỉ cho phép specific commands
command="ansible-playbook",no-port-forwarding,no-X11-forwarding,no-agent-forwarding ssh-ed25519 AAAA...

# Chỉ cho phép từ specific IP
from="192.168.1.100" ssh-ed25519 AAAA...
```

### 4. Backup Private Keys

```bash
# Backup key
cp ~/.ssh/kvm_infrastructure_ed25519 ~/secure-backup/
chmod 600 ~/secure-backup/kvm_infrastructure_ed25519

# Encrypt backup
gpg -c ~/secure-backup/kvm_infrastructure_ed25519
```

### 5. Monitor SSH Access

Trên nodes, monitor SSH logins:

```bash
# View SSH logs
sudo tail -f /var/log/auth.log | grep sshd

# View successful logins
sudo lastlog

# View failed attempts
sudo grep "Failed password" /var/log/auth.log
```

## 🐛 Troubleshooting

### Problem: Permission Denied

```bash
# Check key permissions
ls -la ~/.ssh/kvm_infrastructure_ed25519
# Should be: -rw------- (600)

# Fix
chmod 600 ~/.ssh/kvm_infrastructure_ed25519
chmod 644 ~/.ssh/kvm_infrastructure_ed25519.pub
chmod 700 ~/.ssh
```

### Problem: Key not found

```bash
# Verify key exists
ls -la ~/.ssh/kvm_infrastructure_ed25519

# Check if key is in ssh-agent
ssh-add -l

# Add to agent
ssh-add ~/.ssh/kvm_infrastructure_ed25519
```

### Problem: Host key verification failed

```bash
# Remove old host key
ssh-keygen -R 192.168.1.10
ssh-keygen -R 192.168.1.11

# Or disable checking (dev only)
ssh -o StrictHostKeyChecking=no ubuntu@192.168.1.10
```

### Problem: Connection timeout

```bash
# Test connectivity
ping 192.168.1.10

# Test SSH port
nc -zv 192.168.1.10 22

# Test with verbose
ssh -vvv -i ~/.ssh/kvm_infrastructure_ed25519 ubuntu@192.168.1.10
```

### Problem: Wrong user

```bash
# Check current user on node
ssh -i ~/.ssh/kvm_infrastructure_ed25519 ubuntu@192.168.1.10 "whoami"

# Update .env with correct user
echo "NODE1_USER=ubuntu" >> .env
```

## 📚 Cheatsheet

```bash
# Create key
ssh-keygen -t ed25519 -f ~/.ssh/kvm_key

# Copy to node
ssh-copy-id -i ~/.ssh/kvm_key.pub user@host

# Test connection
ssh -i ~/.ssh/kvm_key user@host

# Add to agent
ssh-add ~/.ssh/kvm_key

# List keys in agent
ssh-add -l

# Remove from agent
ssh-add -d ~/.ssh/kvm_key

# Test Ansible
ansible all -m ping

# Use specific key
ansible all -m ping --private-key ~/.ssh/kvm_key
```

## 🔗 Related Documentation

- [SECURITY.md](SECURITY.md) - General security best practices
- [QUICKSTART.md](QUICKSTART.md) - Quick setup guide
- [README.md](README.md) - Full documentation
- [OpenSSH Documentation](https://www.openssh.com/manual.html)
