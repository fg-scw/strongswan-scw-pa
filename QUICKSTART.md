# Quick Start Guide: StrongSwan VPN for Palo Alto GlobalProtect

## 🚀 5-Minute Setup

### Prerequisites Checklist

- [ ] Ubuntu Server 20.04+ VM on Scaleway with public IP
- [ ] VM attached to Scaleway Private Network (VPC)
- [ ] Palo Alto GlobalProtect gateway public IP
- [ ] Pre-shared key (PSK) from Palo Alto admin
- [ ] Local subnet (Scaleway VPC range)
- [ ] Remote subnet (On-premise network range)
- [ ] Security group allows UDP 500, 4500, ESP, and SSH

### Step 1: Download and Prepare

```bash
# SSH to your Scaleway VM
ssh root@your-scaleway-vm-ip

# Download the script
wget https://your-repo/install_strongswan_vpn.sh
# Or if you have it locally, use scp:
# scp install_strongswan_vpn.sh root@your-scaleway-vm-ip:/root/

# Make executable
chmod +x install_strongswan_vpn.sh
```

### Step 2: Configure

**Option A: Interactive Wizard (Easiest)**

```bash
sudo ./install_strongswan_vpn.sh
```

The wizard will ask for:
1. Palo Alto Gateway IP
2. Remote ID (Gateway FQDN)
3. Pre-Shared Key
4. Local ID
5. Local Subnet (Scaleway VPC)
6. Remote Subnet (On-premise)
7. Network interfaces

**Option B: Edit Script**

```bash
nano install_strongswan_vpn.sh
```

Find and modify these lines:

```bash
PALO_ALTO_GW="203.0.113.1"           # Replace with Palo Alto IP
PALO_ALTO_ID="vpn.company.com"       # Replace with Palo Alto ID
PSK="your-actual-psk-here"           # Replace with your PSK
LOCAL_ID="scaleway-gateway"          # Your gateway name
LOCAL_SUBNET="10.0.0.0/24"           # Your Scaleway VPC subnet
REMOTE_SUBNET="192.168.1.0/24"       # Your on-premise subnet
```

### Step 3: Run Installation

```bash
sudo ./install_strongswan_vpn.sh
```

Installation takes 3-5 minutes. The script will:
- ✅ Install StrongSwan
- ✅ Configure IPsec
- ✅ Set up firewall
- ✅ Enable routing
- ✅ Start services

### Step 4: Verify

```bash
# Check tunnel status
sudo ipsec status

# Expected output:
# Security Associations (1 up, 0 connecting):
# palo-alto-vpn[1]: ESTABLISHED 14 seconds ago

# Test connectivity
ping <on-premise-host-ip>
```

### Step 5: Configure Internal VMs

On each VM in your VPC that needs VPN access:

```bash
# Set StrongSwan VM as gateway (replace 10.0.0.10 with your StrongSwan VM private IP)
sudo ip route add default via 10.0.0.10

# Test connectivity to on-premise
ping <on-premise-host-ip>
```

Make it permanent with netplan:

```bash
sudo nano /etc/netplan/50-cloud-init.yaml
```

Add:

```yaml
network:
    version: 2
    ethernets:
        ens2:
            addresses:
                - 10.0.0.20/24  # This VM's IP
            routes:
                - to: default
                  via: 10.0.0.10  # StrongSwan VM IP
            nameservers:
                addresses:
                    - 8.8.8.8
                    - 8.8.4.4
```

Apply:

```bash
sudo netplan apply
```

## 🔍 Quick Troubleshooting

### Tunnel Not Establishing

```bash
# Check logs
sudo journalctl -u strongswan -n 50

# Common issues:
# - "no IKE proposal chosen" → Encryption mismatch
# - "authentication failed" → Wrong PSK or IDs
# - "no matching IPsec policy" → Subnet mismatch
```

### Tunnel Up But No Traffic

```bash
# Check IP forwarding
sudo sysctl net.ipv4.ip_forward
# Should output: net.ipv4.ip_forward = 1

# Check iptables
sudo iptables -L -v -n

# Check routing
ip route
```

### Cannot Ping On-Premise

```bash
# From StrongSwan VM:
ping <on-premise-ip>

# From internal VM:
# 1. Check default route points to StrongSwan VM
ip route | grep default

# 2. Check StrongSwan VM can be reached
ping 10.0.0.10  # StrongSwan VM private IP

# 3. Test VPN
ping <on-premise-ip>
```

## 📊 Useful Commands

```bash
# View VPN status
/usr/local/bin/vpn-status.sh

# Restart VPN
sudo systemctl restart strongswan

# View live logs
sudo journalctl -u strongswan -f

# Check health
sudo systemctl status vpn-healthcheck

# View active tunnels
sudo ip xfrm state
```

## 🔐 Security Checklist

- [ ] Strong PSK (32+ characters)
- [ ] AES-256 encryption
- [ ] SSH key authentication enabled
- [ ] Firewall rules configured
- [ ] Regular updates scheduled
- [ ] Monitoring enabled
- [ ] Logs reviewed weekly

## 📞 Getting Help

### Check Logs

```bash
sudo journalctl -u strongswan -n 100 --no-pager > vpn-logs.txt
```

### Status Report

```bash
/usr/local/bin/vpn-status.sh > vpn-status.txt
```

### Configuration Files

```bash
sudo cat /etc/ipsec.conf
sudo cat /etc/ipsec.secrets  # Remove PSK before sharing!
```

## 🎯 Common Scenarios

### Scenario 1: Access On-Premise Database

**Goal**: Internal VM needs to access on-premise database server

**On-Premise**: Database at 192.168.1.100:3306

**Steps**:
1. Ensure StrongSwan tunnel is up
2. Configure internal VM to route through StrongSwan
3. Test: `telnet 192.168.1.100 3306`

### Scenario 2: Internet via VPN

**Goal**: Internal VMs without public IPs access internet through VPN

**Configuration**: Already included in script (NAT/MASQUERADE)

**Steps**:
1. Set StrongSwan as default gateway on internal VMs
2. Test: `curl ifconfig.me` (should show on-premise public IP)

### Scenario 3: Multiple Subnets

**Goal**: Access multiple on-premise subnets

**Edit Configuration**:

```bash
sudo nano /etc/ipsec.conf

# Change:
rightsubnet=192.168.1.0/24

# To:
rightsubnet=192.168.1.0/24,192.168.2.0/24,10.20.30.0/24

# Restart
sudo systemctl restart strongswan
```

## 📈 Monitoring Setup

### Enable Email Alerts

```bash
# Install mail
sudo apt-get install mailutils

# Edit health check
sudo nano /usr/local/bin/vpn-healthcheck.sh

# Add email notification (add after log_message function):
send_email() {
    echo "$1" | mail -s "VPN Alert" admin@company.com
}
```

### Set Up Monitoring Dashboard

Use the provided scripts to integrate with your monitoring system:

```bash
# Prometheus example
/usr/local/bin/vpn-status.sh | grep ESTABLISHED
```

## 🔄 Updates and Maintenance

### Weekly Checks

```bash
# Check for updates
sudo apt update
sudo apt list --upgradable

# Review logs
sudo journalctl -u strongswan --since "1 week ago" | grep -i error

# Test connectivity
ping <on-premise-ip>
```

### Monthly Maintenance

```bash
# Backup configuration
sudo /usr/local/bin/backup-vpn-config.sh

# Update system
sudo apt update && sudo apt upgrade -y

# Restart VPN
sudo systemctl restart strongswan
```

## 🆘 Emergency Procedures

### VPN Down

```bash
# Quick restart
sudo systemctl restart strongswan

# If doesn't work, check configuration
sudo ipsec statusall

# Review recent changes
sudo journalctl -u strongswan --since "1 hour ago"

# Contact Palo Alto admin if Phase 1 fails
```

### Routing Issues

```bash
# Reset routing
sudo systemctl restart vpn-routes.service

# Manually add routes if needed
sudo ip route add 192.168.1.0/24 dev eth0
```

### Complete Reset

```bash
# Stop services
sudo systemctl stop strongswan
sudo systemctl stop vpn-healthcheck

# Clear iptables
sudo iptables -F
sudo iptables -t nat -F

# Restart
sudo systemctl start strongswan
sudo systemctl start vpn-healthcheck
```

## ✅ Success Criteria

Your setup is successful when:

1. ✅ `ipsec status` shows "ESTABLISHED"
2. ✅ StrongSwan VM can ping on-premise hosts
3. ✅ Internal VMs can ping on-premise hosts
4. ✅ Internal VMs can access internet (if configured)
5. ✅ No errors in logs
6. ✅ Health check service is running
7. ✅ Tunnel survives reboots

## 📚 Next Steps

1. Configure additional VMs in VPC
2. Set up monitoring and alerting
3. Document your specific subnets and hosts
4. Schedule regular maintenance
5. Test failover scenarios
6. Review security policies

## 🎓 Advanced Topics

See the full README.md for:
- Performance tuning
- High availability setup
- Certificate authentication
- Multiple tunnels
- Advanced routing scenarios
- Integration with monitoring tools

---

**Questions?** Check the full documentation in README.md or review the configuration template in config.template.
