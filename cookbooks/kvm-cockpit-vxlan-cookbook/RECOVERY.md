# Network Recovery Instructions

## Problem

Nodes unreachable after netplan apply during VXLAN configuration.

## Recovery Steps

### On Each Node (via console/IPMI, NOT SSH)

1. **Remove VXLAN netplan config:**

   ```bash
   sudo rm -f /etc/netplan/02-vxlan.yaml
   ```

2. **Apply netplan to restore network:**

   ```bash
   sudo netplan apply
   ```

3. **Verify network connectivity:**

   ```bash
   ip a
   ping -c 3 10.86.140.1
   ```

### After Both Nodes Are Online

Run ansible playbook (VXLAN role is now disabled):

```bash
cd /Users/joinytran/Data/Work/xdev.asia/xdev-asia-labs/kvm-cockpit-vxlan-cookbook
ansible all -m ping
ansible-playbook site.yml -v
```

## What Changed

- VXLAN overlay role has been **commented out** in `site.yml`
- Network bridge configuration is still active
- VM private network (virbr1) is configured
- Cockpit and storage pools will be installed

## To Enable VXLAN Later

When ready to configure VXLAN (requires manual network access):

1. Uncomment the vxlan_overlay role in `site.yml`
2. Run with VXLAN tag only: `ansible-playbook site.yml --tags vxlan`
3. **Important:** Apply netplan from console, not SSH:

   ```bash
   sudo netplan apply
   ```
