#!/bin/bash
# Setup SSH keys for KVM nodes
# This script helps you generate and copy SSH keys to your KVM nodes

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "🔑 SSH Key Setup for KVM Infrastructure"
echo "========================================"
echo ""

# Check if .env exists
if [ ! -f "$PROJECT_ROOT/.env" ]; then
    echo "❌ Error: .env file not found!"
    echo "Please copy .env.example to .env first:"
    echo "  cp .env.example .env"
    exit 1
fi

# Source .env
set -a
source "$PROJECT_ROOT/.env"
set +a

# Default values if not set in .env
SSH_KEY_PATH="${SSH_KEY_PATH:-$HOME/.ssh/kvm_infrastructure_ed25519}"
NODE1_IP="${NODE1_IP:-192.168.1.10}"
NODE2_IP="${NODE2_IP:-192.168.1.11}"
NODE1_USER="${NODE1_USER:-ubuntu}"
NODE2_USER="${NODE2_USER:-ubuntu}"

echo "Configuration:"
echo "  SSH Key Path: $SSH_KEY_PATH"
echo "  Node 1: ${NODE1_USER}@${NODE1_IP}"
echo "  Node 2: ${NODE2_USER}@${NODE2_IP}"
echo ""

# Ask for confirmation
read -p "Continue with SSH key setup? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

# Step 1: Generate SSH key if not exists
if [ -f "$SSH_KEY_PATH" ]; then
    echo "✅ SSH key already exists: $SSH_KEY_PATH"
    read -p "   Use existing key? (y/n) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Please remove the existing key first or specify a different path."
        exit 1
    fi
else
    echo "📝 Generating new SSH key..."
    ssh-keygen -t ed25519 -f "$SSH_KEY_PATH" -C "ansible@kvm-infrastructure" -N ""
    echo "✅ SSH key generated: $SSH_KEY_PATH"
fi

# Step 2: Add to SSH agent
echo ""
echo "🔐 Adding key to SSH agent..."
eval "$(ssh-agent -s)" > /dev/null
ssh-add "$SSH_KEY_PATH" 2>/dev/null || true
echo "✅ Key added to SSH agent"

# Step 3: Copy to Node 1
echo ""
echo "📤 Copying SSH key to Node 1 (${NODE1_USER}@${NODE1_IP})..."
if ssh-copy-id -i "${SSH_KEY_PATH}.pub" "${NODE1_USER}@${NODE1_IP}" 2>/dev/null; then
    echo "✅ SSH key copied to Node 1"
else
    echo "❌ Failed to copy key to Node 1"
    echo "   You may need to:"
    echo "   1. Check if the node is reachable: ping ${NODE1_IP}"
    echo "   2. Verify SSH is running on the node"
    echo "   3. Ensure the user ${NODE1_USER} exists"
    echo "   4. Try manually: ssh-copy-id -i ${SSH_KEY_PATH}.pub ${NODE1_USER}@${NODE1_IP}"
fi

# Step 4: Copy to Node 2
echo ""
echo "📤 Copying SSH key to Node 2 (${NODE2_USER}@${NODE2_IP})..."
if ssh-copy-id -i "${SSH_KEY_PATH}.pub" "${NODE2_USER}@${NODE2_IP}" 2>/dev/null; then
    echo "✅ SSH key copied to Node 2"
else
    echo "❌ Failed to copy key to Node 2"
    echo "   You may need to:"
    echo "   1. Check if the node is reachable: ping ${NODE2_IP}"
    echo "   2. Verify SSH is running on the node"
    echo "   3. Ensure the user ${NODE2_USER} exists"
    echo "   4. Try manually: ssh-copy-id -i ${SSH_KEY_PATH}.pub ${NODE2_USER}@${NODE2_IP}"
fi

# Step 5: Test connections
echo ""
echo "🧪 Testing SSH connections..."
echo ""

echo "Testing Node 1..."
if ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no -o ConnectTimeout=5 "${NODE1_USER}@${NODE1_IP}" "echo 'SSH OK'" 2>/dev/null; then
    echo "✅ Node 1: Connection successful"
else
    echo "❌ Node 1: Connection failed"
fi

echo "Testing Node 2..."
if ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no -o ConnectTimeout=5 "${NODE2_USER}@${NODE2_IP}" "echo 'SSH OK'" 2>/dev/null; then
    echo "✅ Node 2: Connection successful"
else
    echo "❌ Node 2: Connection failed"
fi

# Step 6: Update .env file
echo ""
echo "📝 Updating .env file..."
if grep -q "^SSH_KEY_PATH=" "$PROJECT_ROOT/.env"; then
    # Update existing
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s|^SSH_KEY_PATH=.*|SSH_KEY_PATH=$SSH_KEY_PATH|" "$PROJECT_ROOT/.env"
    else
        sed -i "s|^SSH_KEY_PATH=.*|SSH_KEY_PATH=$SSH_KEY_PATH|" "$PROJECT_ROOT/.env"
    fi
else
    # Add new
    echo "" >> "$PROJECT_ROOT/.env"
    echo "# SSH Configuration (auto-generated)" >> "$PROJECT_ROOT/.env"
    echo "SSH_KEY_PATH=$SSH_KEY_PATH" >> "$PROJECT_ROOT/.env"
fi
echo "✅ .env updated with SSH_KEY_PATH"

# Step 7: Update SSH config (optional)
echo ""
read -p "Add to ~/.ssh/config for easier access? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    SSH_CONFIG="$HOME/.ssh/config"
    
    # Backup
    if [ -f "$SSH_CONFIG" ]; then
        cp "$SSH_CONFIG" "$SSH_CONFIG.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    # Add entries
    cat >> "$SSH_CONFIG" <<EOF

# KVM Infrastructure - Added by setup-ssh-keys.sh
Host kvm-node01 ${NODE1_IP}
    HostName ${NODE1_IP}
    User ${NODE1_USER}
    IdentityFile ${SSH_KEY_PATH}
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

Host kvm-node02 ${NODE2_IP}
    HostName ${NODE2_IP}
    User ${NODE2_USER}
    IdentityFile ${SSH_KEY_PATH}
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
EOF
    
    chmod 600 "$SSH_CONFIG"
    echo "✅ SSH config updated"
    echo ""
    echo "Now you can SSH using:"
    echo "  ssh kvm-node01"
    echo "  ssh kvm-node02"
fi

echo ""
echo "✨ SSH key setup complete!"
echo ""
echo "📋 Next steps:"
echo "1. Test Ansible connection: ansible all -m ping"
echo "2. Generate inventory: ./scripts/generate_inventory.sh"
echo "3. Run playbook: ansible-playbook site.yml"
echo ""
echo "💡 Tips:"
echo "  - Your private key: $SSH_KEY_PATH"
echo "  - Your public key: ${SSH_KEY_PATH}.pub"
echo "  - Keep your private key secure (never share it)"
echo "  - Backup your private key to a safe location"
