#!/bin/bash
# Quick deploy script

set -e

# Check if .env exists
if [ ! -f .env ]; then
    echo "❌ Error: .env file not found!"
    echo "Please copy .env.example to .env and configure it:"
    echo "  cp .env.example .env"
    echo "  vim .env"
    exit 1
fi

# Load environment and generate configs
echo "Loading configuration from .env..."
bash load_env.sh

# Test connection
echo ""
echo "Testing connection to server..."
if ansible all -m ping; then
    echo "✓ Connection successful!"
else
    echo "❌ Connection failed. Please check your .env configuration."
    exit 1
fi

# Run playbook
echo ""
echo "Deploying SeaweedFS..."
ansible-playbook playbook.yml "$@"

echo ""
echo "=========================================="
echo "✓ SeaweedFS deployment completed!"
echo "=========================================="
echo ""
echo "Access your SeaweedFS cluster:"
source .env
echo "  Master UI:  http://${ANSIBLE_HOST}:${MASTER_PORT}"
echo "  Volume API: http://${ANSIBLE_HOST}:${VOLUME_PORT}"
echo "  Filer UI:   http://${ANSIBLE_HOST}:${FILER_PORT}"
echo "  S3 API:     http://${ANSIBLE_HOST}:${S3_PORT}"
echo ""
