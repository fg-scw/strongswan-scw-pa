# StrongSwan VPN Setup - Complete Package

## 📦 What's Included

This package contains everything you need to set up a StrongSwan IPSEC VPN tunnel between Scaleway Cloud and a Palo Alto GlobalProtect endpoint.

### Files

1. **install_strongswan_vpn.sh** (Main Installation Script)
   - Fully automated installation and configuration
   - Interactive wizard for easy setup
   - Configures StrongSwan, firewall, routing, and monitoring
   - Creates health check and monitoring scripts
   - ~600 lines of production-ready code

2. **README.md** (Complete Documentation)
   - Detailed architecture explanation
   - Step-by-step installation guide
   - Palo Alto configuration examples
   - Comprehensive troubleshooting guide
   - Security best practices
   - Performance tuning tips
   - Monitoring and alerting setup

3. **QUICKSTART.md** (Quick Start Guide)
   - 5-minute setup instructions
   - Essential commands reference
   - Common scenarios and solutions
   - Quick troubleshooting tips
   - Emergency procedures

4. **config.template** (Configuration Reference)
   - All configuration parameters explained
   - Cipher suite reference
   - Palo Alto configuration mapping
   - Security recommendations
   - Example configurations
   - Maintenance schedule

## 🎯 Key Features

### Automatic Installation
- ✅ StrongSwan daemon installation
- ✅ IPsec tunnel configuration
- ✅ Kernel parameter optimization
- ✅ Firewall rules (iptables)
- ✅ Routing configuration
- ✅ NAT/MASQUERADE for internet access

### VPC Integration
- ✅ Routes traffic from VPC VMs through tunnel
- ✅ Enables on-premise resource access
- ✅ Provides internet access for VMs without public IPs
- ✅ Single gateway for entire VPC

### Monitoring & Reliability
- ✅ Automatic health checks
- ✅ Dead Peer Detection (DPD)
- ✅ Automatic reconnection
- ✅ Status monitoring script
- ✅ Detailed logging

### Security
- ✅ Strong encryption (AES-256)
- ✅ Configurable cipher suites
- ✅ Firewall rules included
- ✅ PSK protection (600 permissions)
- ✅ IKEv2 support

## 🚀 Quick Start

### Minimum Requirements
- Ubuntu Server 20.04+
- 2 GB RAM
- 1 vCPU
- Public IP address
- Scaleway Private Network (VPC)

### Installation (3 Steps)

1. **Upload script to your Scaleway VM**
   ```bash
   scp install_strongswan_vpn.sh root@your-vm-ip:/root/
   ```

2. **Run the installation script**
   ```bash
   ssh root@your-vm-ip
   chmod +x install_strongswan_vpn.sh
   sudo ./install_strongswan_vpn.sh
   ```

3. **Follow the interactive wizard**
   - Enter Palo Alto gateway IP
   - Enter pre-shared key
   - Enter network subnets
   - Confirm installation

### Configuration

You need the following information from your Palo Alto administrator:

| Parameter | Example | Description |
|-----------|---------|-------------|
| Gateway IP | 203.0.113.1 | Palo Alto public IP |
| Remote ID | vpn.company.com | Gateway identifier |
| Pre-Shared Key | [secret] | PSK for authentication |
| IKE Encryption | aes256-sha256-modp2048 | Phase 1 encryption |
| ESP Encryption | aes256-sha256 | Phase 2 encryption |
| Local Subnet | 10.0.0.0/24 | Scaleway VPC subnet |
| Remote Subnet | 192.168.1.0/24 | On-premise network |

## 📊 Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Scaleway Cloud                            │
│                                                              │
│  ┌────────────── VPC (10.0.0.0/24) ──────────────────────┐ │
│  │                                                         │ │
│  │  ┌──────────────────┐         ┌──────────────────┐   │ │
│  │  │ StrongSwan VM    │         │  Internal VM     │   │ │
│  │  │ Public IP        │◄────────│  No Public IP    │   │ │
│  │  │ Private: 10.0.0.10│        │  Private: 10.0.0.20│  │ │
│  │  └──────────────────┘         └──────────────────┘   │ │
│  │           │                                            │ │
│  └───────────│────────────────────────────────────────────┘ │
│              │                                               │
└──────────────│───────────────────────────────────────────────┘
               │
               │ ═══ IPSEC Tunnel ═══
               │
┌──────────────▼───────────────────────────────────────────────┐
│              Palo Alto GlobalProtect Gateway                  │
│              On-Premise Network (192.168.1.0/24)             │
└───────────────────────────────────────────────────────────────┘
```

### Traffic Flows

1. **VPC → On-Premise**
   - Internal VM (10.0.0.20) → StrongSwan VM (10.0.0.10) → IPSEC Tunnel → On-Premise (192.168.1.0/24)

2. **VPC → Internet**
   - Internal VM (10.0.0.20) → StrongSwan VM (10.0.0.10) → NAT → Internet

3. **On-Premise → VPC**
   - On-Premise Host → IPSEC Tunnel → StrongSwan VM → Internal VM

## 🔧 Post-Installation

### Configure Internal VMs

On each VM in your VPC:

```bash
# Set StrongSwan VM as default gateway
sudo ip route add default via 10.0.0.10

# Make persistent (netplan)
sudo nano /etc/netplan/50-cloud-init.yaml
```

Add:
```yaml
routes:
    - to: default
      via: 10.0.0.10
```

Apply:
```bash
sudo netplan apply
```

### Verify Connectivity

```bash
# From StrongSwan VM
ping 192.168.1.1  # On-premise host

# From internal VM
ping 10.0.0.10    # StrongSwan VM
ping 192.168.1.1  # On-premise host
curl ifconfig.me  # Check internet access
```

## 🔍 Monitoring

### Check Status

```bash
# Quick status
sudo ipsec status

# Detailed status
/usr/local/bin/vpn-status.sh

# Live logs
sudo journalctl -u strongswan -f

# Health check
sudo systemctl status vpn-healthcheck
```

### Automated Monitoring

The installation includes:
- Health check service (monitors every 60 seconds)
- Automatic reconnection on failure
- Logging to /var/log/vpn-healthcheck.log
- Dead Peer Detection (DPD)

## 🛡️ Security

### Included Security Features

1. **Firewall Rules**
   - DROP policy on INPUT and FORWARD
   - Only necessary ports open
   - Connection tracking enabled
   - MSS clamping for MTU issues

2. **Encryption**
   - AES-256 encryption (configurable)
   - SHA-256 authentication (configurable)
   - Perfect Forward Secrecy (PFS)
   - IKEv2 support

3. **Access Control**
   - PSK file permissions (600)
   - Limited service exposure
   - Logging enabled

### Security Recommendations

- ✅ Use strong PSK (32+ characters)
- ✅ Enable SSH key authentication
- ✅ Configure fail2ban
- ✅ Regular updates
- ✅ Monitor logs
- ✅ Rotate PSK quarterly

## 🔧 Troubleshooting

### Common Issues

| Issue | Symptom | Solution |
|-------|---------|----------|
| Phase 1 failure | "no IKE proposal chosen" | Check encryption algorithms match |
| Phase 2 failure | "no matching IPsec policy" | Verify subnets are correct |
| No traffic | Tunnel up but no ping | Check IP forwarding and routes |
| Auth failure | "authentication failed" | Verify PSK matches both sides |

### Debug Mode

Enable verbose logging:
```bash
sudo nano /etc/ipsec.conf
# Change charondebug to level 4
sudo systemctl restart strongswan
sudo journalctl -u strongswan -f
```

## 📚 Documentation Structure

- **QUICKSTART.md**: Start here for rapid deployment
- **README.md**: Complete reference documentation
- **config.template**: All configuration options explained
- **install_strongswan_vpn.sh**: The installation script with inline comments

## 🎓 Learning Path

1. **Beginner**: Follow QUICKSTART.md
2. **Intermediate**: Read README.md sections as needed
3. **Advanced**: Review config.template and customize
4. **Expert**: Modify install_strongswan_vpn.sh for your needs

## 🤝 Palo Alto Configuration

### Required Palo Alto Settings

The script is designed to work with standard Palo Alto GlobalProtect configurations. Your Palo Alto administrator needs to configure:

1. **IKE Gateway**
   - Peer Address: Your Scaleway VM public IP
   - Authentication: Pre-shared Key
   - IKE Crypto Profile (matching the script)

2. **IPsec Tunnel**
   - IKE Gateway (from above)
   - IPsec Crypto Profile (matching the script)
   - Tunnel Interface
   - Proxy ID: Local (on-prem subnet), Remote (Scaleway VPC)

3. **Routing**
   - Static route to Scaleway VPC via tunnel interface

4. **Security Policy**
   - Allow traffic between VPN zone and trust zone

See README.md for detailed Palo Alto configuration examples.

## 🔄 Updates and Maintenance

### Regular Maintenance

- **Weekly**: Check logs and connectivity
- **Monthly**: Update system packages, backup config
- **Quarterly**: Rotate PSK, review security
- **Annually**: Major version updates, architecture review

### Backup Configuration

```bash
# Backup script included
sudo /usr/local/bin/backup-vpn-config.sh

# Backups saved to: /root/vpn-backups/
```

## 📈 Performance

### Expected Performance

- **Throughput**: 500-1000 Mbps (depends on VM size)
- **Latency**: +5-10ms overhead
- **CPU Usage**: 5-20% on 2 vCPU VM
- **Memory**: 200-500 MB

### Optimization

See README.md for:
- Kernel buffer tuning
- TCP optimization
- MTU/MSS settings
- Hardware acceleration

## 🌟 Features by File

### install_strongswan_vpn.sh
- System preparation
- Package installation
- Kernel configuration
- StrongSwan setup
- Firewall configuration
- Routing setup
- Monitoring scripts
- Health checks
- Interactive wizard

### README.md
- Complete architecture
- Installation guide
- Palo Alto examples
- Troubleshooting
- Security practices
- Performance tuning
- Monitoring setup
- Backup procedures

### QUICKSTART.md
- 5-minute setup
- Essential commands
- Quick troubleshooting
- Common scenarios
- Emergency procedures

### config.template
- All parameters
- Cipher reference
- Configuration examples
- Palo Alto mapping
- Security notes

## 🎯 Use Cases

### Supported Scenarios

1. ✅ VPC to On-Premise connectivity
2. ✅ Internet access via VPN for internal VMs
3. ✅ Site-to-site VPN
4. ✅ Remote access to on-premise resources
5. ✅ Hybrid cloud deployment
6. ✅ Multi-cloud networking

### Architecture Patterns

- **Hub-and-Spoke**: StrongSwan as central hub
- **Site-to-Site**: Direct VPC to on-premise
- **Transit Gateway**: Route between multiple networks
- **Backup Link**: Redundant connectivity

## 🆘 Support

### Getting Help

1. Check QUICKSTART.md for quick answers
2. Review README.md troubleshooting section
3. Enable debug logging
4. Collect logs and status output
5. Review Palo Alto logs with your admin

### Useful Commands for Support

```bash
# Generate support bundle
/usr/local/bin/vpn-status.sh > status.txt
sudo journalctl -u strongswan -n 200 > logs.txt
ip addr > network.txt
ip route > routes.txt
sudo iptables -L -v -n > firewall.txt
```

## 📝 Customization

The script is designed to be easily customizable:

1. Edit variables at the top of install_strongswan_vpn.sh
2. Modify cipher suites for your requirements
3. Adjust DPD and lifetime settings
4. Add custom routes in routing section
5. Extend health check functionality

## ✅ Testing Checklist

After installation:

- [ ] `ipsec status` shows ESTABLISHED
- [ ] Can ping Palo Alto gateway
- [ ] Can ping on-premise host from StrongSwan VM
- [ ] Can ping on-premise host from internal VM
- [ ] Internal VM can access internet (if needed)
- [ ] Health check service is running
- [ ] No errors in logs
- [ ] Tunnel survives reboot
- [ ] Failover works correctly

## 🏆 Best Practices

### Deployment
- Test in non-production first
- Document your specific configuration
- Keep backups of working config
- Use version control for customizations

### Operations
- Monitor tunnel status
- Review logs regularly
- Keep system updated
- Test disaster recovery

### Security
- Strong PSK (32+ characters)
- Regular key rotation
- Minimal port exposure
- Audit access logs

## 📦 Package Contents Summary

| File | Lines | Purpose |
|------|-------|---------|
| install_strongswan_vpn.sh | ~600 | Main installation script |
| README.md | ~1000 | Complete documentation |
| QUICKSTART.md | ~400 | Quick start guide |
| config.template | ~500 | Configuration reference |

**Total**: ~2500 lines of production-ready code and documentation

## 🎓 Additional Resources

- [StrongSwan Documentation](https://docs.strongswan.org/)
- [Palo Alto GlobalProtect Docs](https://docs.paloaltonetworks.com/)
- [Scaleway VPC Guide](https://www.scaleway.com/en/docs/network/vpc/)
- [IPSEC RFC 4301](https://tools.ietf.org/html/rfc4301)

---

## 🚀 Ready to Deploy?

1. Read QUICKSTART.md
2. Gather required information from Palo Alto admin
3. Run the installation script
4. Configure internal VMs
5. Test connectivity
6. Set up monitoring

**That's it! You now have a production-ready IPSEC VPN tunnel between Scaleway and Palo Alto.**

---

*For questions or issues, refer to the comprehensive troubleshooting section in README.md*
