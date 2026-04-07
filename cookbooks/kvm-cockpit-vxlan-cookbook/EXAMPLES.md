# Example: Creating VMs using the playbook

## Example 1: Create a simple VM with NAT network

```bash
# SSH to kvm-node01
ssh kvm-node01

# Download cloud image
cd /var/lib/libvirt/images
sudo wget https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img

# Create VM disk
sudo qemu-img create -f qcow2 -F qcow2 -b jammy-server-cloudimg-amd64.img vm-web-01.qcow2 20G

# Create cloud-init
sudo mkdir -p /var/lib/libvirt/cloud-init
sudo tee /var/lib/libvirt/cloud-init/vm-web-01-meta << EOF
instance-id: vm-web-01
local-hostname: vm-web-01
EOF

sudo tee /var/lib/libvirt/cloud-init/vm-web-01-user << EOF
#cloud-config
hostname: vm-web-01
users:
  - name: ubuntu
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
      - ssh-rsa AAAAB3... your-key-here
EOF

sudo cloud-localds vm-web-01-cidata.iso \
    /var/lib/libvirt/cloud-init/vm-web-01-user \
    /var/lib/libvirt/cloud-init/vm-web-01-meta

# Create VM
sudo virt-install \
    --name vm-web-01 \
    --memory 4096 \
    --vcpus 2 \
    --disk path=/var/lib/libvirt/images/vm-web-01.qcow2,format=qcow2 \
    --disk path=/var/lib/libvirt/images/vm-web-01-cidata.iso,device=cdrom \
    --os-variant ubuntu22.04 \
    --network network=vm-private \
    --graphics none \
    --import \
    --noautoconsole
```

## Example 2: Create VMs on both nodes with VXLAN network

```bash
# On kvm-node01 - Create Kubernetes master
sudo virt-install \
    --name k8s-master \
    --memory 4096 \
    --vcpus 2 \
    --disk path=/var/lib/libvirt/images/k8s-master.qcow2,size=30 \
    --os-variant ubuntu22.04 \
    --network network=vxlan-net \
    --network bridge=br0 \
    --graphics vnc \
    --cdrom /var/lib/libvirt/images/ubuntu-22.04-server-amd64.iso \
    --noautoconsole

# On kvm-node02 - Create Kubernetes worker
sudo virt-install \
    --name k8s-worker-01 \
    --memory 8192 \
    --vcpus 4 \
    --disk path=/var/lib/libvirt/images/k8s-worker-01.qcow2,size=50 \
    --os-variant ubuntu22.04 \
    --network network=vxlan-net \
    --network bridge=br0 \
    --graphics vnc \
    --cdrom /var/lib/libvirt/images/ubuntu-22.04-server-amd64.iso \
    --noautoconsole
```

## Example 3: Ansible playbook for creating multiple VMs

Create a new playbook `create-vms.yml`:

```yaml
---
- name: Create multiple VMs
  hosts: kvm-node01
  become: yes
  
  vars:
    vms:
      - name: web-server-01
        memory: 2048
        vcpus: 2
        disk_size: 20
        network: vm-private
      
      - name: db-server-01
        memory: 4096
        vcpus: 2
        disk_size: 50
        network: vm-private
      
      - name: app-server-01
        memory: 4096
        vcpus: 4
        disk_size: 30
        network: vxlan-net
  
  tasks:
    - name: Download Ubuntu cloud image
      get_url:
        url: https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img
        dest: /var/lib/libvirt/images/ubuntu-22.04-cloudimg.img
        mode: '0644'
    
    - name: Create VM disk images
      command: >
        qemu-img create -f qcow2 -F qcow2
        -b /var/lib/libvirt/images/ubuntu-22.04-cloudimg.img
        /var/lib/libvirt/images/{{ item.name }}.qcow2
        {{ item.disk_size }}G
      loop: "{{ vms }}"
      args:
        creates: /var/lib/libvirt/images/{{ item.name }}.qcow2
    
    - name: Create cloud-init meta-data
      copy:
        content: |
          instance-id: {{ item.name }}
          local-hostname: {{ item.name }}
        dest: /tmp/{{ item.name }}-meta-data
      loop: "{{ vms }}"
    
    - name: Create cloud-init user-data
      copy:
        content: |
          #cloud-config
          hostname: {{ item.name }}
          users:
            - name: ubuntu
              sudo: ALL=(ALL) NOPASSWD:ALL
              shell: /bin/bash
              plain_text_passwd: 'ubuntu123'
              lock_passwd: false
          package_update: true
          packages:
            - qemu-guest-agent
        dest: /tmp/{{ item.name }}-user-data
      loop: "{{ vms }}"
    
    - name: Create cloud-init ISO
      command: >
        cloud-localds /var/lib/libvirt/images/{{ item.name }}-cidata.iso
        /tmp/{{ item.name }}-user-data
        /tmp/{{ item.name }}-meta-data
      loop: "{{ vms }}"
      args:
        creates: /var/lib/libvirt/images/{{ item.name }}-cidata.iso
    
    - name: Create VMs
      command: >
        virt-install
        --name {{ item.name }}
        --memory {{ item.memory }}
        --vcpus {{ item.vcpus }}
        --disk path=/var/lib/libvirt/images/{{ item.name }}.qcow2,format=qcow2
        --disk path=/var/lib/libvirt/images/{{ item.name }}-cidata.iso,device=cdrom
        --os-variant ubuntu22.04
        --network network={{ item.network }}
        --graphics none
        --import
        --noautoconsole
      loop: "{{ vms }}"
      register: vm_creation
      failed_when: 
        - vm_creation.rc != 0
        - "'already exists' not in vm_creation.stderr"
    
    - name: Wait for VMs to get IP
      wait_for:
        timeout: 30
    
    - name: Get VM IP addresses
      command: virsh domifaddr {{ item.name }}
      loop: "{{ vms }}"
      register: vm_ips
      changed_when: false
    
    - name: Display VM information
      debug:
        msg: 
          - "VM: {{ item.item.name }}"
          - "{{ item.stdout_lines }}"
      loop: "{{ vm_ips.results }}"
```

Run it:

```bash
ansible-playbook create-vms.yml
```

## Example 4: VM management commands

```bash
# List all VMs
virsh list --all

# Start VM
virsh start vm-web-01

# Stop VM gracefully
virsh shutdown vm-web-01

# Force stop VM
virsh destroy vm-web-01

# Restart VM
virsh reboot vm-web-01

# Auto-start VM on boot
virsh autostart vm-web-01

# Console access
virsh console vm-web-01

# Get VM info
virsh dominfo vm-web-01

# Get VM IP
virsh domifaddr vm-web-01

# Create snapshot
virsh snapshot-create-as vm-web-01 --name "before-update" --description "Snapshot before system update"

# List snapshots
virsh snapshot-list vm-web-01

# Revert to snapshot
virsh snapshot-revert vm-web-01 before-update

# Delete snapshot
virsh snapshot-delete vm-web-01 before-update

# Clone VM
virt-clone --original vm-web-01 --name vm-web-02 --auto-clone

# Delete VM
virsh shutdown vm-web-01
virsh undefine vm-web-01 --remove-all-storage
```
