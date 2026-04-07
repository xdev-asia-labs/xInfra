#!/bin/bash
# Generate Ansible configuration from .env file

set -e

echo "🔧 Generating Ansible configuration from .env..."

# Check if .env exists
if [ ! -f .env ]; then
    echo "❌ Error: .env file not found!"
    echo "Please copy .env.example to .env and configure it:"
    echo "  cp .env.example .env"
    echo "  vim .env"
    exit 1
fi

# Source .env file
set -a
source .env
set +a

echo "✅ Loaded configuration from .env"

# Generate inventory.yml
cat > inventory.yml <<EOF
all:
  children:
    kvm_hosts:
      hosts:
        ${NODE1_NAME:-kvm-node01}:
          ansible_host: ${NODE1_IP:-192.168.1.10}
          host_ip: ${NODE1_IP:-192.168.1.10}
          vxlan_remote_ip: ${NODE2_IP:-192.168.1.11}
          vm_ip_range_start: 100
          vm_ip_range_end: 149
          dhcp_range_start: "${NODE1_DHCP_START:-10.10.10.100}"
          dhcp_range_end: "${NODE1_DHCP_END:-10.10.10.149}"
        
        ${NODE2_NAME:-kvm-node02}:
          ansible_host: ${NODE2_IP:-192.168.1.11}
          host_ip: ${NODE2_IP:-192.168.1.11}
          vxlan_remote_ip: ${NODE1_IP:-192.168.1.10}
          vm_ip_range_start: 150
          vm_ip_range_end: 199
          dhcp_range_start: "${NODE2_DHCP_START:-10.10.10.150}"
          dhcp_range_end: "${NODE2_DHCP_END:-10.10.10.200}"
      
      vars:
        ansible_user: ${NODE1_USER:-ubuntu}
        ansible_become: yes
        ansible_python_interpreter: /usr/bin/python3
EOF

echo "✅ Generated inventory.yml"

# Generate group_vars/all.yml
mkdir -p group_vars

# Convert comma-separated DNS to YAML array
IFS=',' read -ra DNS_ARRAY <<< "${DNS_SERVERS:-8.8.8.8,8.8.4.4}"
DNS_YAML=""
for dns in "${DNS_ARRAY[@]}"; do
    DNS_YAML="${DNS_YAML}  - $(echo $dns | xargs)\n"
done

cat > group_vars/all.yml <<EOF
---
# Network Configuration
gateway: ${NETWORK_GATEWAY:-192.168.1.1}
network_cidr: ${NETWORK_CIDR:-24}
dns_servers:
$(echo -e "$DNS_YAML")
# Physical Network Interface
primary_interface: ${PRIMARY_INTERFACE:-enp0s3}

# Bridge Configuration
bridge_name: ${BRIDGE_NAME:-br0}
bridge_mtu: ${BRIDGE_MTU:-1500}
bridge_stp: ${BRIDGE_STP:-true}
bridge_forward_delay: ${BRIDGE_FORWARD_DELAY:-4}

# Virtual Network Configuration
vm_private_network_name: ${VM_PRIVATE_NETWORK_NAME:-vm-private}
vm_private_subnet: ${VM_PRIVATE_SUBNET:-10.10.10.0/24}
vm_private_gateway: ${VM_PRIVATE_GATEWAY:-10.10.10.1}
vm_private_bridge: ${VM_PRIVATE_BRIDGE:-virbr1}

# VXLAN Configuration
vxlan_interface: ${VXLAN_INTERFACE:-vxlan100}
vxlan_vni: ${VXLAN_VNI:-100}
vxlan_port: ${VXLAN_PORT:-4789}
vxlan_bridge: ${VXLAN_BRIDGE:-vxlan-br0}
vxlan_mtu: ${VXLAN_MTU:-1450}
vxlan_network_name: ${VXLAN_NETWORK_NAME:-vxlan-net}

# Storage Configuration
storage_pool_name: ${STORAGE_POOL_NAME:-default}
storage_pool_path: ${STORAGE_POOL_PATH:-/var/lib/libvirt/images}

# Cockpit Configuration
cockpit_port: ${COCKPIT_PORT:-9090}
enable_firewall: ${ENABLE_FIREWALL:-false}

# KVM Packages
kvm_packages:
  - qemu-kvm
  - libvirt-daemon-system
  - libvirt-clients
  - bridge-utils
  - virtinst
  - virt-manager
  - libguestfs-tools
  - libosinfo-bin
  - cloud-image-utils
  - cpu-checker

# Cockpit Packages
cockpit_packages:
  - cockpit
  - cockpit-machines

# Nested Virtualization
enable_nested_virt: ${ENABLE_NESTED_VIRT:-false}

# Libvirt Users
libvirt_users:
  - "{{ ansible_user }}"
EOF

echo "✅ Generated group_vars/all.yml"

echo ""
echo "✨ Configuration generated successfully!"
echo ""
echo "📋 Next steps:"
echo "1. Review the generated files: inventory.yml and group_vars/all.yml"
echo "2. Test connection: ansible all -m ping"
echo "3. Run playbook: ansible-playbook site.yml"
