#!/bin/bash
# Minimal StrongSwan + iptables setup for Palo Alto GlobalProtect on Ubuntu 20.04+

set -e

#-------------------------------------------------------------------------------
# Vérification root
#-------------------------------------------------------------------------------
if [[ "$EUID" -ne 0 ]]; then
  echo "Ce script doit être exécuté en root." >&2
  exit 1
fi

#-------------------------------------------------------------------------------
# CONFIGURATION À ADAPTER
#-------------------------------------------------------------------------------

# Palo Alto GlobalProtect
PALO_ALTO_GW=""      # IP du gateway Palo Alto
PALO_ALTO_ID=""      # Remote ID (FQDN ou IP)
PSK=""               # Pre-Shared Key
LOCAL_ID=""          # ID local (identifiant de ce serveur)

# Réseaux
LOCAL_SUBNET=""      # Subnet VPC (ex: 10.0.0.0/24)
REMOTE_SUBNET=""     # Subnet distant (ex: 192.168.1.0/24)
VPC_INTERFACE="ens2" # Interface privée
WAN_INTERFACE="ens2" # Interface WAN

# IKE / ESP
IKE_ENCRYPTION="aes256-sha256-modp2048"
ESP_ENCRYPTION="aes256-sha256"
KEYEXCHANGE="ikev2"   # ikev1 ou ikev2

# DPD / durées
DPD_DELAY="30s"
DPD_TIMEOUT="120s"
REKEY_TIME="4h"
LIFETIME="24h"

#-------------------------------------------------------------------------------
# Validation minimale de la configuration
#-------------------------------------------------------------------------------
missing=0
for var in PALO_ALTO_GW PALO_ALTO_ID PSK LOCAL_ID LOCAL_SUBNET REMOTE_SUBNET; do
  if [[ -z "${!var}" ]]; then
    echo "Variable de config manquante: $var" >&2
    missing=1
  fi
done

if [[ "$missing" -ne 0 ]]; then
  echo "Veuillez renseigner toutes les variables de configuration avant d'exécuter le script." >&2
  exit 1
fi

#-------------------------------------------------------------------------------
# Installation des paquets nécessaires
#-------------------------------------------------------------------------------
echo "[*] Installation des paquets..."
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  strongswan \
  iptables \
  iptables-persistent

#-------------------------------------------------------------------------------
# Paramètres noyau (IP forwarding + rp_filter)
#-------------------------------------------------------------------------------
echo "[*] Configuration des paramètres noyau..."
cat >/etc/sysctl.d/99-vpn.conf <<EOF
net.ipv4.ip_forward = 1

# Désactiver rp_filter pour l'IPsec (sinon routage asymétrique posé problème)
net.ipv4.conf.all.rp_filter = 0
net.ipv4.conf.default.rp_filter = 0
net.ipv4.conf.$WAN_INTERFACE.rp_filter = 0
net.ipv4.conf.$VPC_INTERFACE.rp_filter = 0
EOF

sysctl -p /etc/sysctl.d/99-vpn.conf

#-------------------------------------------------------------------------------
# Configuration StrongSwan (ipsec.conf / ipsec.secrets)
#-------------------------------------------------------------------------------
echo "[*] Configuration de StrongSwan..."

# Sauvegarde rapide si existant
[ -f /etc/ipsec.conf ] && cp /etc/ipsec.conf /etc/ipsec.conf.bak.$(date +%s)
[ -f /etc/ipsec.secrets ] && cp /etc/ipsec.secrets /etc/ipsec.secrets.bak.$(date +%s)

cat >/etc/ipsec.conf <<EOF
config setup
  uniqueids=never

conn %default
  ikelifetime=$LIFETIME
  keylife=$REKEY_TIME
  keyexchange=$KEYEXCHANGE
  dpdaction=restart
  dpddelay=$DPD_DELAY
  dpdtimeout=$DPD_TIMEOUT
  keyingtries=%forever
  mobike=no

conn palo-alto-vpn
  left=%defaultroute
  leftid="$LOCAL_ID"
  leftsubnet=$LOCAL_SUBNET
  leftfirewall=yes

  right=$PALO_ALTO_GW
  rightid="$PALO_ALTO_ID"
  rightsubnet=$REMOTE_SUBNET

  authby=secret
  ike=$IKE_ENCRYPTION!
  esp=$ESP_ENCRYPTION!
  type=tunnel
  auto=start
EOF

cat >/etc/ipsec.secrets <<EOF
: PSK "$PSK"
EOF
chmod 600 /etc/ipsec.secrets

#-------------------------------------------------------------------------------
# Règles iptables minimales (input + forward + NAT)
#-------------------------------------------------------------------------------
echo "[*] Configuration des règles iptables..."

# Flush de base
iptables -F
iptables -t nat -F
iptables -X

# Politiques par défaut
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# Loopback
iptables -A INPUT -i lo -j ACCEPT

# Connexions établies
iptables -A INPUT   -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# SSH (adapter le port si nécessaire)
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# IPsec / IKE
iptables -A INPUT -p udp --dport 500  -j ACCEPT
iptables -A INPUT -p udp --dport 4500 -j ACCEPT
iptables -A INPUT -p esp -j ACCEPT
iptables -A INPUT -p ah  -j ACCEPT

# ICMP (utile pour le debug, pas strictement obligatoire)
iptables -A INPUT -p icmp -j ACCEPT

# Forward entre VPC et subnet distant
iptables -A FORWARD -s "$LOCAL_SUBNET"  -d "$REMOTE_SUBNET" -j ACCEPT
iptables -A FORWARD -s "$REMOTE_SUBNET" -d "$LOCAL_SUBNET"  -j ACCEPT

# NAT pour le trafic VPC vers Internet (hors subnet distant)
iptables -t nat -A POSTROUTING -s "$LOCAL_SUBNET" -o "$WAN_INTERFACE" ! -d "$REMOTE_SUBNET" -j MASQUERADE

# Sauvegarde des règles (si iptables-persistent est présent)
netfilter-persistent save || true

#-------------------------------------------------------------------------------
# Démarrage StrongSwan
#-------------------------------------------------------------------------------
echo "[*] Activation et redémarrage du service StrongSwan..."
systemctl enable strongswan
systemctl restart strongswan

echo
echo "[OK] Installation minimale StrongSwan terminée."
echo "Vérification :"
echo "  ipsec status"
echo "  journalctl -u strongswan -f"
