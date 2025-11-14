#!/bin/bash
set -e

echo "=== Installation et configuration StrongSwan (IPsec ↔ Palo Alto) ==="

# Vérification root
if [[ $EUID -ne 0 ]]; then
  echo "Ce script doit être lancé en root." >&2
  exit 1
fi

# Récupération IP publique par défaut (si possible)
DEFAULT_PUB_IP=$(hostname -I 2>/dev/null | awk '{print $1}')

read -p "Nom de la connexion [palo-alto-vpn] : " CONN_NAME
CONN_NAME=${CONN_NAME:-palo-alto-vpn}

read -p "IP publique du Palo Alto (vue depuis cette VM, ex: 51.159.162.39) : " PA_PUBLIC
read -p "ID du Palo Alto (souvent son IP interne, ex: 172.16.8.2) : " PA_ID

read -p "Sous-réseau LOCAL (côté StrongSwan, ex: 172.16.32.0/22) : " LOCAL_SUBNET
read -p "Sous-réseau DISTANT (côté Palo Alto, ex: 172.16.12.0/22) : " REMOTE_SUBNET

read -p "ID local (IP publique de cette VM) [${DEFAULT_PUB_IP}] : " LOCAL_ID
LOCAL_ID=${LOCAL_ID:-$DEFAULT_PUB_IP}

read -sp "Clé pré-partagée (PSK) : " PSK
echo ""

echo "=== Installation des paquets StrongSwan ==="
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y strongswan strongswan-pki libcharon-extra-plugins

echo "=== Génération de /etc/ipsec.conf ==="
cat >/etc/ipsec.conf <<EOF
config setup
    charondebug="ike 2, knl 2, cfg 2, net 2"
    uniqueids=never

conn ${CONN_NAME}
    keyexchange=ikev2
    type=tunnel
    auto=start

    ike=aes256-sha256-modp2048!
    esp=aes256-sha256!

    left=%defaultroute
    leftid=${LOCAL_ID}
    leftsubnet=${LOCAL_SUBNET}
    leftauth=psk
    leftfirewall=yes

    right=${PA_PUBLIC}
    rightid=${PA_ID}
    rightsubnet=${REMOTE_SUBNET}
    rightauth=psk

    authby=psk

    dpdaction=restart
    dpddelay=30s
    dpdtimeout=120s
EOF

echo "=== Génération de /etc/ipsec.secrets ==="
cat >/etc/ipsec.secrets <<EOF
: PSK "${PSK}"
EOF
chmod 600 /etc/ipsec.secrets

echo "=== Activation / redémarrage StrongSwan ==="
systemctl enable strongswan-starter >/dev/null 2>&1 || true
systemctl restart strongswan-starter

echo
echo "=== État du VPN ==="
ipsec statusall || true

echo
echo "Terminé. Vérifie maintenant que Palo Alto voit bien l'IKE SA (show vpn ike-sa)."
