# StrongSwan VPN Gateway for Palo Alto GlobalProtect

## Overview

This setup creates an IPSEC VPN tunnel between a Scaleway VM running StrongSwan and a Palo Alto GlobalProtect endpoint. The StrongSwan VM acts as a VPN gateway for your entire Scaleway VPC, allowing:

1. **VPC to On-Premise connectivity**: VMs in the same VPC can access on-premise resources through the tunnel
2. **Internet access via VPN**: VPC VMs without public IPs can route internet traffic through the StrongSwan gateway
3. **Centralized VPN management**: Single point of VPN configuration and monitoring

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Scaleway Cloud                           │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │                  VPC (10.0.0.0/24)                     │  │
│  │                                                         │  │
│  │  ┌─────────────────────┐       ┌──────────────────┐  │  │
│  │  │ StrongSwan Gateway  │       │   Internal VM    │  │  │
│  │  │  (10.0.0.10)        │───────│   (10.0.0.20)    │  │  │
│  │  │  Public IP: X.X.X.X │       │   No Public IP   │  │  │
│  │  └─────────────────────┘       └──────────────────┘  │  │
│  │           │                                            │  │
│  └───────────│────────────────────────────────────────────┘  │
│              │                                               │
└──────────────│───────────────────────────────────────────────┘
               │
               │ IPSEC Tunnel
               │
┌──────────────▼───────────────────────────────────────────────┐
│                   Internet                                    │
└──────────────▲───────────────────────────────────────────────┘
               │
┌──────────────┴───────────────────────────────────────────────┐
│                On-Premise Network                             │
│                                                               │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  Palo Alto GlobalProtect Gateway                     │    │
│  │  (Y.Y.Y.Y)                                          │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                               │
│  Internal Network: 192.168.1.0/24                           │
│                                                               │
└───────────────────────────────────────────────────────────────┘
```

## Prerequisites

### On Scaleway

1. **VM Instance**:
   - Ubuntu Server 20.04 or later
   - At least 2 GB RAM
   - 1 vCPU minimum (2 vCPUs recommended)
   - Public IP attached

2. **VPC Configuration**:
   - Create a Private Network (VPC)
   - Attach the StrongSwan VM to the VPC
   - Attach other VMs to the same VPC
   - Configure the StrongSwan VM as the default gateway for other VMs

3. **Security Group Rules**:
   - Allow UDP port 500 (IKE)
   - Allow UDP port 4500 (NAT-T)
   - Allow ESP protocol (IP protocol 50)
   - Allow AH protocol (IP protocol 51)
   - Allow SSH (TCP port 22)

### On Palo Alto

1. **GlobalProtect Gateway Configuration**:
   - Site-to-Site VPN configured
   - IKE gateway and crypto profile defined
   - IPsec tunnel configuration
   - Pre-shared key (PSK) configured
   - Proxy IDs matching local and remote subnets

2. **Required Information**:
   - Gateway public IP address
   - Pre-shared key (PSK)
   - IKE version (IKEv1 or IKEv2)
   - Encryption algorithms (IKE and ESP)
   - DH group
   - Local and remote subnet definitions

## Installation

### Step 1: Prepare the Configuration

Edit the script variables or use the interactive wizard:

```bash
# Download the script
wget https://your-repo/install_strongswan_vpn.sh
chmod +x install_strongswan_vpn.sh

# Edit configuration variables (option 1)
nano install_strongswan_vpn.sh

# Or run with interactive wizard (option 2)
sudo ./install_strongswan_vpn.sh
```

### Step 2: Required Configuration Variables

```bash
# Palo Alto GlobalProtect Configuration
PALO_ALTO_GW="x.x.x.x"              # Public IP of Palo Alto
PALO_ALTO_ID="vpn.company.com"      # Remote ID
PSK="your-pre-shared-key"           # Pre-shared key
LOCAL_ID="scaleway-gateway"         # Local identifier

# Network Configuration
LOCAL_SUBNET="10.0.0.0/24"          # Your Scaleway VPC subnet
REMOTE_SUBNET="192.168.1.0/24"      # On-premise subnet
VPC_INTERFACE="ens2"                # Private interface
WAN_INTERFACE="ens2"                # Public interface

# Encryption Settings (match Palo Alto config)
IKE_ENCRYPTION="aes256-sha256-modp2048"
ESP_ENCRYPTION="aes256-sha256"
KEYEXCHANGE="ikev2"
```

### Step 3: Run Installation

```bash
sudo ./install_strongswan_vpn.sh
```

The script will:
1. Update the system
2. Install StrongSwan and dependencies
3. Configure kernel parameters
4. Set up IPsec configuration
5. Configure firewall rules
6. Set up routing
7. Create monitoring scripts
8. Start services
9. Verify installation

## Post-Installation Configuration

### Configure Other VMs in the VPC

For VMs in the same VPC to use the StrongSwan gateway:

1. **Set the StrongSwan VM as default gateway**:

```bash
# On each internal VM
sudo ip route add default via 10.0.0.10  # StrongSwan VM private IP
```

2. **Make it persistent** (on internal VMs):

```bash
# Using netplan (Ubuntu 20.04+)
sudo nano /etc/netplan/50-cloud-init.yaml
```

Add gateway configuration:

```yaml
network:
    version: 2
    ethernets:
        ens2:
            addresses:
                - 10.0.0.20/24
            routes:
                - to: default
                  via: 10.0.0.10
            nameservers:
                addresses:
                    - 8.8.8.8
                    - 8.8.4.4
```

Apply:

```bash
sudo netplan apply
```

### Configure Static Routes (Optional)

If you need specific routes:

```bash
# Add route to on-premise subnet via VPN
sudo ip route add 192.168.1.0/24 via 10.0.0.10

# Make it persistent
echo "up ip route add 192.168.1.0/24 via 10.0.0.10" | sudo tee -a /etc/network/interfaces
```

## Palo Alto Configuration

### Example IKE Gateway Configuration

```
Network > Network Profiles > IKE Crypto

Profile Name: StrongSwan-IKE
DH Group: group14 (modp2048)
Encryption: aes-256-cbc
Authentication: sha256
Key Lifetime: 8 hours
```

### Example IPsec Crypto Profile

```
Network > Network Profiles > IPsec Crypto

Profile Name: StrongSwan-IPsec
Protocol: ESP
Encryption: aes-256-cbc
Authentication: sha256
DH Group: group14
Lifetime: 4 hours
```

### Example IKE Gateway

```
Network > Network Profiles > IKE Gateways

Name: Scaleway-Gateway
Version: IKEv2
Interface: outside
Peer Address: <Scaleway Public IP>
Pre-shared Key: <your-psk>
IKE Crypto Profile: StrongSwan-IKE
```

### Example IPsec Tunnel

```
Network > IPsec Tunnels

Name: Scaleway-Tunnel
IKE Gateway: Scaleway-Gateway
IPsec Crypto Profile: StrongSwan-IPsec

Tunnel Interface: tunnel.1

Proxy ID:
  Local: 192.168.1.0/24
  Remote: 10.0.0.0/24
  Protocol: Any
```

### Example Routing

```
Network > Virtual Routers > default

Static Routes:
  Name: Scaleway-VPC
  Destination: 10.0.0.0/24
  Interface: tunnel.1
```

### Example Security Policy

```
Policies > Security

Name: VPN-to-OnPremise
Source Zone: vpn-zone
Destination Zone: trust
Application: any
Service: application-default
Action: Allow
```

## Management Commands

### Check VPN Status

```bash
# Detailed status
/usr/local/bin/vpn-status.sh

# Quick status
sudo ipsec status

# Specific tunnel
sudo ipsec status palo-alto-vpn

# Connection details
sudo ipsec statusall
```

### Manage VPN Connection

```bash
# Restart VPN
sudo systemctl restart strongswan

# Stop VPN
sudo systemctl stop strongswan

# Start VPN
sudo systemctl start strongswan

# Enable on boot
sudo systemctl enable strongswan
```

### View Logs

```bash
# Live logs
sudo journalctl -u strongswan -f

# Recent logs
sudo journalctl -u strongswan -n 100

# Health check logs
sudo tail -f /var/log/vpn-healthcheck.log
```

### Test Connectivity

```bash
# From StrongSwan VM to on-premise
ping 192.168.1.1

# From internal VM to on-premise
ping 192.168.1.1

# Check routing
ip route

# Check active tunnels
ip xfrm state
ip xfrm policy
```

## Troubleshooting

### VPN Tunnel Not Establishing

1. **Check configuration**:
```bash
sudo ipsec statusall
sudo journalctl -u strongswan -n 100
```

2. **Verify network connectivity**:
```bash
# Can reach Palo Alto gateway?
ping <PALO_ALTO_GW>

# Check UDP ports
sudo tcpdump -i any -n udp port 500 or udp port 4500
```

3. **Check firewall rules**:
```bash
sudo iptables -L -v -n
sudo iptables -t nat -L -v -n
```

4. **Verify kernel parameters**:
```bash
sysctl net.ipv4.ip_forward
sysctl net.ipv4.conf.all.rp_filter
```

### Common Issues

#### Phase 1 Failure (IKE)

**Symptoms**: `no IKE proposal chosen` or `no matching peer found`

**Solutions**:
- Verify IKE encryption algorithms match on both sides
- Check pre-shared key is correct
- Ensure IDs match (LOCAL_ID and PALO_ALTO_ID)
- Verify IKE version (IKEv1 vs IKEv2)

#### Phase 2 Failure (IPsec)

**Symptoms**: `no matching IPsec policy found` or `TS unacceptable`

**Solutions**:
- Verify proxy IDs match (local and remote subnets)
- Check ESP encryption algorithms
- Ensure both sides use same protocol (ESP)

#### Packets Not Routing

**Symptoms**: Tunnel up but no connectivity

**Solutions**:
```bash
# Check IP forwarding
sudo sysctl net.ipv4.ip_forward

# Enable if needed
sudo sysctl -w net.ipv4.ip_forward=1

# Check iptables rules
sudo iptables -L FORWARD -v -n

# Verify routing on internal VMs
ip route
```

#### MSS/MTU Issues

**Symptoms**: Some connections work, others timeout

**Solutions**:
```bash
# Check current MTU
ip link show

# Set MTU on VPN interface
sudo ip link set dev eth0 mtu 1400

# Add MSS clamping (already in script)
sudo iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
```

### Debug Mode

Enable verbose logging:

```bash
# Edit /etc/ipsec.conf
sudo nano /etc/ipsec.conf

# Change charondebug to:
charondebug="ike 4, knl 4, cfg 4, net 4, esp 4, dmn 4, mgr 4"

# Restart StrongSwan
sudo systemctl restart strongswan

# Watch logs
sudo journalctl -u strongswan -f
```

## Security Considerations

### Best Practices

1. **Use Strong Encryption**:
   - Minimum AES-256 for encryption
   - SHA-256 or better for authentication
   - DH group 14 (modp2048) or higher

2. **Firewall Hardening**:
   - Only allow necessary ports
   - Implement rate limiting for IKE
   - Use fail2ban for SSH protection

3. **Key Management**:
   - Store PSK securely
   - Rotate keys regularly
   - Use strong, random PSKs (32+ characters)

4. **Monitoring**:
   - Enable health checks
   - Monitor tunnel status
   - Set up alerts for tunnel down events

5. **Updates**:
   - Keep StrongSwan updated
   - Apply security patches promptly
   - Monitor security advisories

### Securing the PSK

```bash
# Ensure proper permissions
sudo chmod 600 /etc/ipsec.secrets

# Audit who can access
sudo ls -la /etc/ipsec.secrets

# Consider using certificate authentication for production
```

## Performance Tuning

### For High-Throughput Scenarios

```bash
# Increase kernel buffers
sudo sysctl -w net.core.rmem_max=16777216
sudo sysctl -w net.core.wmem_max=16777216
sudo sysctl -w net.ipv4.tcp_rmem='4096 87380 16777216'
sudo sysctl -w net.ipv4.tcp_wmem='4096 65536 16777216'

# Enable TCP window scaling
sudo sysctl -w net.ipv4.tcp_window_scaling=1
```

### Optimize for Latency

```bash
# Reduce DPD intervals
# Edit /etc/ipsec.conf:
dpddelay=10s
dpdtimeout=30s
```

## Backup and Recovery

### Backup Configuration

```bash
# Create backup script
sudo cat > /usr/local/bin/backup-vpn-config.sh <<'EOF'
#!/bin/bash
BACKUP_DIR="/root/vpn-backups"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

tar czf $BACKUP_DIR/vpn-config-$DATE.tar.gz \
    /etc/ipsec.conf \
    /etc/ipsec.secrets \
    /etc/sysctl.d/99-vpn.conf \
    /etc/systemd/system/vpn-*.service \
    /usr/local/bin/*vpn*.sh

echo "Backup created: $BACKUP_DIR/vpn-config-$DATE.tar.gz"
EOF

sudo chmod +x /usr/local/bin/backup-vpn-config.sh
```

### Restore Configuration

```bash
# Extract backup
sudo tar xzf vpn-config-YYYYMMDD_HHMMSS.tar.gz -C /

# Restart services
sudo systemctl daemon-reload
sudo systemctl restart strongswan
```

## Monitoring and Alerting

### Set Up Email Alerts

```bash
# Install mailutils
sudo apt-get install mailutils

# Modify health check to send email
sudo nano /usr/local/bin/vpn-healthcheck.sh

# Add email function:
send_alert() {
    echo "$1" | mail -s "VPN Alert: $2" admin@company.com
}
```

### Integration with Monitoring Tools

```bash
# Example: Prometheus node_exporter

# Create custom metrics
cat > /var/lib/node_exporter/textfile_collector/vpn_status.prom <<EOF
# HELP vpn_tunnel_status VPN tunnel status (1=up, 0=down)
# TYPE vpn_tunnel_status gauge
vpn_tunnel_status 1
EOF
```

## Additional Resources

- [StrongSwan Documentation](https://docs.strongswan.org/)
- [Palo Alto Networks Documentation](https://docs.paloaltonetworks.com/)
- [Scaleway VPC Documentation](https://www.scaleway.com/en/docs/network/vpc/)

## Support

For issues specific to:
- **StrongSwan**: Check logs and StrongSwan documentation
- **Palo Alto**: Consult your Palo Alto administrator
- **Scaleway**: Contact Scaleway support for VPC issues

## License

This script is provided as-is for use with Scaleway and Palo Alto infrastructure.
