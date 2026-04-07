#!/bin/bash
# Script to load .env and generate inventory dynamically

set -a
source .env
set +a

# Generate inventory file from .env
cat > inventory/hosts.ini <<EOF
[seaweedfs_all:children]
seaweedfs_single

[seaweedfs_single]
seaweedfs-node ansible_host=${ANSIBLE_HOST} ansible_user=${ANSIBLE_USER} ansible_ssh_private_key_file=${ANSIBLE_SSH_PRIVATE_KEY_FILE}
EOF

# Generate group_vars from .env
cat > group_vars/all.yml <<EOF
---
# SeaweedFS version
seaweedfs_version: "${SEAWEEDFS_VERSION}"

# Installation paths
seaweedfs_install_dir: "${SEAWEEDFS_INSTALL_DIR}"
seaweedfs_data_dir: "${SEAWEEDFS_DATA_DIR}"
seaweedfs_log_dir: "${SEAWEEDFS_LOG_DIR}"
s3_config_dir: "${S3_CONFIG_DIR:-/etc/seaweedfs}"

# Master settings
master_port: ${MASTER_PORT}
master_peers: "${MASTER_PEERS}"

# Volume settings
volume_port: ${VOLUME_PORT}
volume_max: ${VOLUME_MAX}
volume_mserver: "${VOLUME_MSERVER}"

# Filer settings
filer_port: ${FILER_PORT}
filer_master: "${FILER_MASTER}"

# S3 API settings
s3_port: ${S3_PORT}
s3_filer: "${S3_FILER}"
s3_admin_access_key: "${S3_ADMIN_ACCESS_KEY}"
s3_admin_secret_key: "${S3_ADMIN_SECRET_KEY}"

# Replication
default_replication: "${DEFAULT_REPLICATION}"

# Download URL
seaweedfs_download_url: "https://github.com/seaweedfs/seaweedfs/releases/download/{{ seaweedfs_version }}/linux_amd64.tar.gz"
EOF

echo "✓ Configuration loaded from .env"
echo "✓ Generated inventory/hosts.ini"
echo "✓ Generated group_vars/all.yml"
