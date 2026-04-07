# Security & Best Practices

## 🔐 Securing Sensitive Information

### 1. Using .env File (Recommended)

The `.env` file contains all configuration information and should **NEVER** be committed to git.

```bash
# Step 1: Copy .env.example to .env
cp .env.example .env

# Step 2: Edit .env with your actual information
vim .env

# Step 3: Generate inventory and group_vars from .env
./scripts/generate_inventory.sh
# Or
python3 scripts/generate_inventory.py

# Step 4: Run playbook
ansible-playbook site.yml
```

**Note**: Files `inventory.yml` and `group_vars/all.yml` are already added to `.gitignore`.

### 2. Using Ansible Vault (For Passwords)

If you need to store passwords or highly sensitive information:

```bash
# Create vault file for passwords
ansible-vault create group_vars/vault.yml

# vault.yml content:
---
vault_ansible_become_pass: your_sudo_password
vault_ssh_password: your_ssh_password
vault_vm_passwords:
  ubuntu: ubuntu_vm_password
  admin: admin_password
```

Use in playbook:

```yaml
# group_vars/all.yml
ansible_become_pass: "{{ vault_ansible_become_pass }}"
ansible_ssh_pass: "{{ vault_ssh_password }}"
```

Run with vault:

```bash
# Use password prompt
ansible-playbook site.yml --ask-vault-pass

# Or use password file
echo "your_vault_password" > .vault_pass
chmod 600 .vault_pass
ansible-playbook site.yml --vault-password-file .vault_pass
```

### 3. Using SSH Keys Instead of Passwords (RECOMMENDED)

SSH keys are much more secure than passwords. This is the best practice for infrastructure automation.

📖 **Detailed guide**: See [SSH_KEYS_GUIDE.md](SSH_KEYS_GUIDE.md)

#### Quick Setup with Script

```bash
# Run automated script
./scripts/setup-ssh-keys.sh
```

The script will automatically:

1. Create SSH key pair (ed25519)
2. Copy public key to all nodes
3. Test connections
4. Update .env and inventory
5. Add to ~/.ssh/config (optional)

#### Manual Setup

**Step 1: Create SSH key**

```bash
# ed25519 (recommended)
ssh-keygen -t ed25519 -f ~/.ssh/kvm_infrastructure_ed25519 -C "ansible@kvm-infrastructure"

# Set permissions
chmod 600 ~/.ssh/kvm_infrastructure_ed25519
chmod 644 ~/.ssh/kvm_infrastructure_ed25519.pub
```

**Step 2: Copy key to nodes**

```bash
ssh-copy-id -i ~/.ssh/kvm_infrastructure_ed25519.pub ubuntu@192.168.1.10
ssh-copy-id -i ~/.ssh/kvm_infrastructure_ed25519.pub ubuntu@192.168.1.11
```

**Step 3: Test**

```bash
ssh -i ~/.ssh/kvm_infrastructure_ed25519 ubuntu@192.168.1.10 "hostname"
ssh -i ~/.ssh/kvm_infrastructure_ed25519 ubuntu@192.168.1.11 "hostname"
```

**Step 4: Update .env**

```bash
echo "SSH_KEY_PATH=~/.ssh/kvm_infrastructure_ed25519" >> .env
```

Update inventory:

```yaml
# inventory.yml (or use generate_inventory.sh script)
all:
  children:
    kvm_hosts:
      vars:
        ansible_ssh_private_key_file: ~/.ssh/kvm_infrastructure_ed25519
        ansible_user: ubuntu
```

Then test:

```bash
# Test Ansible ping
ansible all -m ping

# Run playbook
ansible-playbook site.yml
```

## 📂 Files to Commit vs Not Commit

### ✅ SHOULD commit (example files)

```
.env.example
inventory.yml.example
group_vars/all.yml.example
host_vars/*.yml.example
README.md
SECURITY.md
roles/
scripts/
```

### ❌ NEVER commit

```
.env
*.env (except .env.example)
inventory.yml
group_vars/all.yml
host_vars/*.yml (actual files)
.vault_pass
vault_*.yml (actual vault files)
```

## 🔒 Git Pre-commit Hook

Create hook to prevent committing sensitive files:

```bash
# .git/hooks/pre-commit
#!/bin/bash

SENSITIVE_FILES=(
    ".env"
    "inventory.yml"
    "group_vars/all.yml"
    ".vault_pass"
)

for file in "${SENSITIVE_FILES[@]}"; do
    if git diff --cached --name-only | grep -q "^${file}$"; then
        echo "❌ ERROR: Attempting to commit sensitive file: ${file}"
        echo "This file should not be committed to git!"
        exit 1
    fi
done

exit 0
```

Activate:

```bash
chmod +x .git/hooks/pre-commit
```

## 🛡️ Best Practices

### 1. File Permissions

```bash
# .env and vault files should be owner-readable only
chmod 600 .env
chmod 600 .vault_pass
chmod 600 group_vars/vault.yml

# Scripts should be executable
chmod +x scripts/*.sh
```

### 2. Separate Environments

```bash
# Development
.env.dev

# Staging
.env.staging

# Production
.env.production

# Usage:
cp .env.production .env
./scripts/generate_inventory.sh
```

### 3. Using Environment Variables

```bash
# Export from .env
export $(cat .env | grep -v '^#' | xargs)

# Run playbook
ansible-playbook site.yml
```

### 4. Audit Trail

```bash
# Log configuration changes
git log --all --full-history -- inventory.yml.example
git log --all --full-history -- .env.example
```

## 🔍 Check Before Committing

```bash
# Check for sensitive files
git status

# View diff
git diff --cached

# List files to be committed
git diff --cached --name-only

# Ensure sensitive files are gitignored
git check-ignore .env inventory.yml group_vars/all.yml
# Should output the file names if they're properly ignored
```

## 🚨 If You Accidentally Committed Sensitive Files

### Remove from history (DANGEROUS - only use before pushing)

```bash
# Remove file from all commits
git filter-branch --force --index-filter \
    'git rm --cached --ignore-unmatch .env' \
    --prune-empty --tag-name-filter cat -- --all

# Force push (if already pushed)
git push origin --force --all
```

### Using BFG Repo-Cleaner (Safer)

```bash
# Install BFG
brew install bfg  # macOS
# or download from https://rtyley.github.io/bfg-repo-cleaner/

# Delete file
bfg --delete-files .env

# Clean up
git reflog expire --expire=now --all
git gc --prune=now --aggressive
```

### Revoke Credentials Immediately

If you've pushed credentials to git:

1. Change all passwords immediately
2. Revoke SSH keys
3. Rotate API tokens
4. Update .env with new credentials
5. Re-generate inventory

## 📝 .env Template

Always keep `.env.example` up to date with the template:

```bash
# Update .env.example when adding new variables
# Never copy real values into .env.example
# Only use placeholders or example values
```

## 🔄 Recommended Workflow

```bash
# 1. Clone repo
git clone <repo>
cd kvm-cockpit-vxlan-cookbook

# 2. Setup environment
cp .env.example .env
vim .env  # Fill in real information

# 3. Generate configs
./scripts/generate_inventory.sh

# 4. Verify
git status  # Ensure .env, inventory.yml don't appear

# 5. Work on code
vim roles/*/tasks/main.yml

# 6. Commit only code changes
git add roles/
git commit -m "Update role xyz"

# 7. Push
git push origin main
```

## 📚 References

- [Ansible Vault Documentation](https://docs.ansible.com/ansible/latest/user_guide/vault.html)
- [Git Security Best Practices](https://owasp.org/www-project-secure-coding-practices-quick-reference-guide/)
- [12 Factor App - Config](https://12factor.net/config)
