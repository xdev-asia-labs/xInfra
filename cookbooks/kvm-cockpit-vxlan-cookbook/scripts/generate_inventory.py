#!/usr/bin/env python3
"""
Generate Ansible inventory from .env file
Usage: python3 scripts/generate_inventory.py
"""

import os
import sys
from pathlib import Path

def load_env(env_file='.env'):
    """Load environment variables from .env file"""
    env_vars = {}
    env_path = Path(env_file)
    
    if not env_path.exists():
        print(f"Error: {env_file} not found!")
        print("Please copy .env.example to .env and configure it.")
        sys.exit(1)
    
    with open(env_path, 'r') as f:
        for line in f:
            line = line.strip()
            # Skip comments and empty lines
            if not line or line.startswith('#'):
                continue
            
            # Parse KEY=VALUE
            if '=' in line:
                key, value = line.split('=', 1)
                env_vars[key.strip()] = value.strip()
    
    return env_vars

def parse_dns_servers(dns_str):
    """Parse comma-separated DNS servers"""
    return [ip.strip() for ip in dns_str.split(',') if ip.strip()]

def generate_inventory(env_vars):
    """Generate inventory.yml from environment variables"""
    
    dns_servers = parse_dns_servers(env_vars.get('DNS_SERVERS', '8.8.8.8,8.8.4.4'))
    dns_yaml = '\n'.join([f'  - {dns}' for dns in dns_servers])
    
    inventory = f"""all:
  children:
    kvm_hosts:
      hosts:
        {env_vars.get('NODE1_NAME', 'kvm-node01')}:
          ansible_host: {env_vars.get('NODE1_IP', '192.168.1.10')}
          host_ip: {env_vars.get('NODE1_IP', '192.168.1.10')}
          vxlan_remote_ip: {env_vars.get('NODE2_IP', '192.168.1.11')}
          vm_ip_range_start: 100
          vm_ip_range_end: 149
          dhcp_range_start: "{env_vars.get('NODE1_DHCP_START', '10.10.10.100')}"
          dhcp_range_end: "{env_vars.get('NODE1_DHCP_END', '10.10.10.149')}"
        
        {env_vars.get('NODE2_NAME', 'kvm-node02')}:
          ansible_host: {env_vars.get('NODE2_IP', '192.168.1.11')}
          host_ip: {env_vars.get('NODE2_IP', '192.168.1.11')}
          vxlan_remote_ip: {env_vars.get('NODE1_IP', '192.168.1.10')}
          vm_ip_range_start: 150
          vm_ip_range_end: 199
          dhcp_range_start: "{env_vars.get('NODE2_DHCP_START', '10.10.10.150')}"
          dhcp_range_end: "{env_vars.get('NODE2_DHCP_END', '10.10.10.200')}"
      
      vars:
        ansible_user: {env_vars.get('NODE1_USER', 'ubuntu')}
        ansible_become: yes
        ansible_python_interpreter: /usr/bin/python3
"""
    
    return inventory

def generate_group_vars(env_vars):
    """Generate group_vars/all.yml from environment variables"""
    
    dns_servers = parse_dns_servers(env_vars.get('DNS_SERVERS', '8.8.8.8,8.8.4.4'))
    dns_yaml = '\n'.join([f'  - {dns}' for dns in dns_servers])
    
    group_vars = f"""---
# Network Configuration
gateway: {env_vars.get('NETWORK_GATEWAY', '192.168.1.1')}
network_cidr: {env_vars.get('NETWORK_CIDR', '24')}
dns_servers:
{dns_yaml}

# Physical Network Interface
primary_interface: {env_vars.get('PRIMARY_INTERFACE', 'enp0s3')}

# Bridge Configuration
bridge_name: {env_vars.get('BRIDGE_NAME', 'br0')}
bridge_mtu: {env_vars.get('BRIDGE_MTU', '1500')}
bridge_stp: {env_vars.get('BRIDGE_STP', 'true')}
bridge_forward_delay: {env_vars.get('BRIDGE_FORWARD_DELAY', '4')}

# Virtual Network Configuration
vm_private_network_name: {env_vars.get('VM_PRIVATE_NETWORK_NAME', 'vm-private')}
vm_private_subnet: {env_vars.get('VM_PRIVATE_SUBNET', '10.10.10.0/24')}
vm_private_gateway: {env_vars.get('VM_PRIVATE_GATEWAY', '10.10.10.1')}
vm_private_bridge: {env_vars.get('VM_PRIVATE_BRIDGE', 'virbr1')}

# VXLAN Configuration
vxlan_interface: {env_vars.get('VXLAN_INTERFACE', 'vxlan100')}
vxlan_vni: {env_vars.get('VXLAN_VNI', '100')}
vxlan_port: {env_vars.get('VXLAN_PORT', '4789')}
vxlan_bridge: {env_vars.get('VXLAN_BRIDGE', 'vxlan-br0')}
vxlan_mtu: {env_vars.get('VXLAN_MTU', '1450')}
vxlan_network_name: {env_vars.get('VXLAN_NETWORK_NAME', 'vxlan-net')}

# Storage Configuration
storage_pool_name: {env_vars.get('STORAGE_POOL_NAME', 'default')}
storage_pool_path: {env_vars.get('STORAGE_POOL_PATH', '/var/lib/libvirt/images')}

# Cockpit Configuration
cockpit_port: {env_vars.get('COCKPIT_PORT', '9090')}
enable_firewall: {env_vars.get('ENABLE_FIREWALL', 'false')}

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
enable_nested_virt: {env_vars.get('ENABLE_NESTED_VIRT', 'false')}

# Libvirt Users
libvirt_users:
  - "{{{{ ansible_user }}}}"
"""
    
    return group_vars

def main():
    """Main function"""
    print("🔧 Generating Ansible configuration from .env...")
    
    # Load .env file
    env_vars = load_env()
    print(f"✅ Loaded {len(env_vars)} variables from .env")
    
    # Generate inventory.yml
    inventory_content = generate_inventory(env_vars)
    with open('inventory.yml', 'w') as f:
        f.write(inventory_content)
    print("✅ Generated inventory.yml")
    
    # Generate group_vars/all.yml
    group_vars_content = generate_group_vars(env_vars)
    os.makedirs('group_vars', exist_ok=True)
    with open('group_vars/all.yml', 'w') as f:
        f.write(group_vars_content)
    print("✅ Generated group_vars/all.yml")
    
    print("\n✨ Configuration generated successfully!")
    print("\n📋 Next steps:")
    print("1. Review the generated files: inventory.yml and group_vars/all.yml")
    print("2. Test connection: ansible all -m ping")
    print("3. Run playbook: ansible-playbook site.yml")

if __name__ == '__main__':
    main()
