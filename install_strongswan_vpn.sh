#!/bin/bash

################################################################################
# StrongSwan VPN Gateway Setup for Palo Alto GlobalProtect
# Ubuntu Server 20.04+
# 
# This script installs and configures StrongSwan to create an IPSEC VPN tunnel
# to a Palo Alto GlobalProtect endpoint and sets up routing for Scaleway VPC
################################################################################

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root"
   exit 1
fi

################################################################################
# CONFIGURATION SECTION - MODIFY THESE VALUES
################################################################################

# Palo Alto GlobalProtect Configuration
PALO_ALTO_GW=""                    # Palo Alto GlobalProtect Gateway IP
PALO_ALTO_ID=""                    # Remote ID (usually the gateway FQDN or IP)
PSK=""                             # Pre-Shared Key
LOCAL_ID=""                        # Local ID (this server's identifier)

# Network Configuration
LOCAL_SUBNET=""                    # Scaleway VPC subnet (e.g., "10.0.0.0/24")
REMOTE_SUBNET=""                   # On-premise subnet to access (e.g., "192.168.1.0/24")
VPC_INTERFACE="ens2"               # Private network interface in Scaleway
WAN_INTERFACE="ens2"               # Public interface (adjust if different)

# IKE/ESP Configuration (adjust based on Palo Alto settings)
IKE_ENCRYPTION="aes256-sha256-modp2048"
ESP_ENCRYPTION="aes256-sha256"
KEYEXCHANGE="ikev2"                # ikev1 or ikev2
AGGRESSIVE_MODE="no"               # Set to "yes" for IKEv1 aggressive mode

# Advanced Options
DPD_DELAY="30s"                    # Dead Peer Detection delay
DPD_TIMEOUT="120s"                 # Dead Peer Detection timeout
REKEY_TIME="4h"                    # Rekey time
LIFETIME="24h"                     # Connection lifetime

################################################################################
# VALIDATION
################################################################################

validate_config() {
    log "Validating configuration..."
    
    local errors=0
    
    if [[ -z "$PALO_ALTO_GW" ]]; then
        error "PALO_ALTO_GW is not set"
        ((errors++))
    fi
    
    if [[ -z "$PSK" ]]; then
        error "PSK (Pre-Shared Key) is not set"
        ((errors++))
    fi
    
    if [[ -z "$LOCAL_SUBNET" ]]; then
        error "LOCAL_SUBNET is not set"
        ((errors++))
    fi
    
    if [[ -z "$REMOTE_SUBNET" ]]; then
        error "REMOTE_SUBNET is not set"
        ((errors++))
    fi
    
    if [[ $errors -gt 0 ]]; then
        error "Configuration validation failed. Please set all required variables."
        exit 1
    fi
    
    log "Configuration validated successfully"
}

################################################################################
# SYSTEM PREPARATION
################################################################################

prepare_system() {
    log "Updating system packages..."
    apt-get update
    
    log "Installing required packages..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        strongswan \
        strongswan-pki \
        libcharon-extra-plugins \
        libcharon-extauth-plugins \
        libstrongswan-extra-plugins \
        iptables \
        iptables-persistent \
        net-tools \
        tcpdump
    
    log "System preparation completed"
}

################################################################################
# KERNEL PARAMETERS
################################################################################

configure_kernel() {
    log "Configuring kernel parameters for IP forwarding and VPN..."
    
    cat > /etc/sysctl.d/99-vpn.conf <<EOF
# IP Forwarding
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1

# Disable ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv6.conf.all.accept_redirects = 0

# Disable source packet routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0

# Enable strict reverse path filtering
net.ipv4.conf.all.rp_filter = 1

# Ignore ICMP ping requests
net.ipv4.icmp_echo_ignore_all = 0

# StrongSwan specific
net.ipv4.conf.all.rp_filter = 0
net.ipv4.conf.default.rp_filter = 0
net.ipv4.conf.$WAN_INTERFACE.rp_filter = 0
net.ipv4.conf.$VPC_INTERFACE.rp_filter = 0
EOF
    
    sysctl -p /etc/sysctl.d/99-vpn.conf
    
    log "Kernel parameters configured"
}

################################################################################
# STRONGSWAN CONFIGURATION
################################################################################

configure_strongswan() {
    log "Configuring StrongSwan..."
    
    # Backup existing configuration
    if [[ -f /etc/ipsec.conf ]]; then
        cp /etc/ipsec.conf /etc/ipsec.conf.backup.$(date +%Y%m%d_%H%M%S)
    fi
    
    if [[ -f /etc/ipsec.secrets ]]; then
        cp /etc/ipsec.secrets /etc/ipsec.secrets.backup.$(date +%Y%m%d_%H%M%S)
    fi
    
    # Create ipsec.conf
    cat > /etc/ipsec.conf <<EOF
# StrongSwan configuration for Palo Alto GlobalProtect
config setup
    charondebug="ike 2, knl 2, cfg 2, net 2, esp 2, dmn 2, mgr 2"
    uniqueids=never

conn %default
    ikelifetime=$LIFETIME
    keylife=$REKEY_TIME
    rekeymargin=3m
    keyingtries=%forever
    keyexchange=$KEYEXCHANGE
    mobike=no
    dpdaction=restart
    dpddelay=$DPD_DELAY
    dpdtimeout=$DPD_TIMEOUT

conn palo-alto-vpn
    # Connection details
    left=%defaultroute
    leftid="$LOCAL_ID"
    leftsubnet=$LOCAL_SUBNET
    leftfirewall=yes
    
    right=$PALO_ALTO_GW
    rightid="$PALO_ALTO_ID"
    rightsubnet=$REMOTE_SUBNET
    
    # Authentication
    authby=secret
    
    # Phase 1 (IKE)
    ike=$IKE_ENCRYPTION!
    
    # Phase 2 (ESP)
    esp=$ESP_ENCRYPTION!
    
    # Connection management
    auto=start
    type=tunnel
    compress=no
    
    # Aggressive mode (IKEv1 only)
    aggressive=$AGGRESSIVE_MODE
EOF

    # Create ipsec.secrets
    cat > /etc/ipsec.secrets <<EOF
# Pre-Shared Key for Palo Alto GlobalProtect
: PSK "$PSK"
EOF

    chmod 600 /etc/ipsec.secrets
    
    log "StrongSwan configuration completed"
}

################################################################################
# FIREWALL CONFIGURATION
################################################################################

configure_firewall() {
    log "Configuring iptables firewall rules..."
    
    # Flush existing rules
    iptables -F
    iptables -t nat -F
    iptables -t mangle -F
    iptables -X
    
    # Default policies
    iptables -P INPUT DROP
    iptables -P FORWARD DROP
    iptables -P OUTPUT ACCEPT
    
    # Allow loopback
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A OUTPUT -o lo -j ACCEPT
    
    # Allow established connections
    iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    
    # Allow SSH (adjust port if needed)
    iptables -A INPUT -p tcp --dport 22 -j ACCEPT
    
    # IPSEC/IKE traffic
    iptables -A INPUT -p udp --dport 500 -j ACCEPT
    iptables -A INPUT -p udp --dport 4500 -j ACCEPT
    iptables -A INPUT -p esp -j ACCEPT
    iptables -A INPUT -p ah -j ACCEPT
    
    # Allow ICMP (ping)
    iptables -A INPUT -p icmp -j ACCEPT
    
    # VPC to On-Premise forwarding
    iptables -A FORWARD -s $LOCAL_SUBNET -d $REMOTE_SUBNET -j ACCEPT
    iptables -A FORWARD -s $REMOTE_SUBNET -d $LOCAL_SUBNET -j ACCEPT
    
    # VPC to Internet forwarding (NAT)
    iptables -t nat -A POSTROUTING -s $LOCAL_SUBNET -o $WAN_INTERFACE ! -d $REMOTE_SUBNET -j MASQUERADE
    
    # MSS clamping for VPN
    iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
    
    # Save rules
    netfilter-persistent save
    
    log "Firewall rules configured and saved"
}

################################################################################
# ROUTING CONFIGURATION
################################################################################

configure_routing() {
    log "Configuring routing for VPC..."
    
    # Create systemd service for route management
    cat > /etc/systemd/system/vpn-routes.service <<EOF
[Unit]
Description=VPN Route Management
After=network.target strongswan.service
Requires=strongswan.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/bin/setup-vpn-routes.sh
ExecStop=/usr/local/bin/cleanup-vpn-routes.sh

[Install]
WantedBy=multi-user.target
EOF

    # Create route setup script
    cat > /usr/local/bin/setup-vpn-routes.sh <<'EOF'
#!/bin/bash
# Wait for VPN to establish
sleep 10

# Add specific routes if needed
# ip route add DESTINATION via GATEWAY dev INTERFACE

# Log route setup
logger "VPN routes configured"
EOF

    # Create route cleanup script
    cat > /usr/local/bin/cleanup-vpn-routes.sh <<'EOF'
#!/bin/bash
# Cleanup routes if needed
logger "VPN routes cleaned up"
EOF

    chmod +x /usr/local/bin/setup-vpn-routes.sh
    chmod +x /usr/local/bin/cleanup-vpn-routes.sh
    
    systemctl daemon-reload
    systemctl enable vpn-routes.service
    
    log "Routing configuration completed"
}

################################################################################
# MONITORING SCRIPT
################################################################################

create_monitoring_script() {
    log "Creating monitoring script..."
    
    cat > /usr/local/bin/vpn-status.sh <<'EOF'
#!/bin/bash

echo "==================================="
echo "StrongSwan VPN Status"
echo "==================================="
echo ""

echo "--- IPsec Status ---"
ipsec status
echo ""

echo "--- Active Tunnels ---"
ip xfrm state
echo ""

echo "--- Routing Table ---"
ip route
echo ""

echo "--- Connection Statistics ---"
ipsec statusall
echo ""

echo "--- Recent Logs ---"
journalctl -u strongswan -n 50 --no-pager
EOF

    chmod +x /usr/local/bin/vpn-status.sh
    
    log "Monitoring script created at /usr/local/bin/vpn-status.sh"
}

################################################################################
# HEALTH CHECK SCRIPT
################################################################################

create_healthcheck_script() {
    log "Creating health check script..."
    
    cat > /usr/local/bin/vpn-healthcheck.sh <<EOF
#!/bin/bash

# Configuration
REMOTE_HOST="$PALO_ALTO_GW"
CHECK_INTERVAL=60
LOG_FILE="/var/log/vpn-healthcheck.log"

log_message() {
    echo "\$(date '+%Y-%m-%d %H:%M:%S') - \$1" >> "\$LOG_FILE"
}

# Check if VPN tunnel is up
check_tunnel() {
    if ipsec status palo-alto-vpn | grep -q "ESTABLISHED"; then
        return 0
    else
        return 1
    fi
}

# Check connectivity to remote gateway
check_connectivity() {
    if ping -c 1 -W 5 "\$REMOTE_HOST" > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Main monitoring loop
while true; do
    if ! check_tunnel; then
        log_message "WARNING: VPN tunnel is down. Attempting restart..."
        ipsec restart
        sleep 30
        
        if check_tunnel; then
            log_message "SUCCESS: VPN tunnel restored"
        else
            log_message "ERROR: Failed to restore VPN tunnel"
        fi
    fi
    
    if ! check_connectivity; then
        log_message "WARNING: Cannot ping remote gateway"
    fi
    
    sleep \$CHECK_INTERVAL
done
EOF

    chmod +x /usr/local/bin/vpn-healthcheck.sh
    
    # Create systemd service for health check
    cat > /etc/systemd/system/vpn-healthcheck.service <<EOF
[Unit]
Description=VPN Health Check Service
After=strongswan.service
Requires=strongswan.service

[Service]
Type=simple
ExecStart=/usr/local/bin/vpn-healthcheck.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable vpn-healthcheck.service
    
    log "Health check script and service created"
}

################################################################################
# SERVICE MANAGEMENT
################################################################################

start_services() {
    log "Starting services..."
    
    systemctl enable strongswan
    systemctl restart strongswan
    
    systemctl start vpn-routes.service
    systemctl start vpn-healthcheck.service
    
    log "Services started"
}

################################################################################
# POST-INSTALLATION VERIFICATION
################################################################################

verify_installation() {
    log "Verifying installation..."
    
    sleep 5
    
    echo ""
    echo "==================================="
    echo "Installation Complete!"
    echo "==================================="
    echo ""
    
    # Check StrongSwan status
    if systemctl is-active --quiet strongswan; then
        echo -e "${GREEN}✓${NC} StrongSwan service is running"
    else
        echo -e "${RED}✗${NC} StrongSwan service is not running"
    fi
    
    # Check tunnel status
    if ipsec status palo-alto-vpn | grep -q "ESTABLISHED"; then
        echo -e "${GREEN}✓${NC} VPN tunnel is established"
    else
        echo -e "${YELLOW}!${NC} VPN tunnel is not yet established (may take a few moments)"
    fi
    
    echo ""
    echo "Useful commands:"
    echo "  - Check VPN status: /usr/local/bin/vpn-status.sh"
    echo "  - View logs: journalctl -u strongswan -f"
    echo "  - Restart VPN: systemctl restart strongswan"
    echo "  - Check health: systemctl status vpn-healthcheck"
    echo ""
    echo "Configuration files:"
    echo "  - /etc/ipsec.conf"
    echo "  - /etc/ipsec.secrets"
    echo ""
    echo "Log files:"
    echo "  - /var/log/vpn-healthcheck.log"
    echo ""
}

################################################################################
# CONFIGURATION WIZARD (OPTIONAL)
################################################################################

configuration_wizard() {
    echo "==================================="
    echo "StrongSwan VPN Configuration Wizard"
    echo "==================================="
    echo ""
    
    read -p "Palo Alto GlobalProtect Gateway IP: " PALO_ALTO_GW
    read -p "Remote ID (Gateway FQDN or IP): " PALO_ALTO_ID
    read -sp "Pre-Shared Key (PSK): " PSK
    echo ""
    read -p "Local ID (this server identifier): " LOCAL_ID
    read -p "Local Subnet (Scaleway VPC, e.g., 10.0.0.0/24): " LOCAL_SUBNET
    read -p "Remote Subnet (On-premise, e.g., 192.168.1.0/24): " REMOTE_SUBNET
    read -p "VPC Interface (default: ens2): " VPC_INTERFACE
    VPC_INTERFACE=${VPC_INTERFACE:-ens2}
    read -p "WAN Interface (default: ens2): " WAN_INTERFACE
    WAN_INTERFACE=${WAN_INTERFACE:-ens2}
    
    echo ""
    echo "Configuration summary:"
    echo "  Gateway: $PALO_ALTO_GW"
    echo "  Local Subnet: $LOCAL_SUBNET"
    echo "  Remote Subnet: $REMOTE_SUBNET"
    echo ""
    read -p "Proceed with installation? (yes/no): " confirm
    
    if [[ "$confirm" != "yes" ]]; then
        echo "Installation cancelled"
        exit 0
    fi
}

################################################################################
# MAIN EXECUTION
################################################################################

main() {
    log "Starting StrongSwan VPN installation..."
    
    # Check if configuration is provided
    if [[ -z "$PALO_ALTO_GW" ]]; then
        configuration_wizard
    fi
    
    validate_config
    prepare_system
    configure_kernel
    configure_strongswan
    configure_firewall
    configure_routing
    create_monitoring_script
    create_healthcheck_script
    start_services
    verify_installation
    
    log "Installation completed successfully!"
}

# Run main function
main "$@"
