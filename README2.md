# Tunnel IPsec Palo Alto ↔ StrongSwan

## Topologie

- **Palo Alto VM-Series**
  - Management : 51.159.83.78 (hors VPN)
  - `ethernet1/1` (TRUST-ZONE) : 172.16.12.2/22
  - `ethernet1/2` (UNTRUST-ZONE) : 172.16.8.2/22
  - Default gateway : 172.16.8.3 (Internet/NAT Gateway Scaleway)
  - LAN local : `172.16.12.0/22`

- **NAT Gateway Scaleway**
  - IP publique : `51.159.162.39`
  - IP privée : `172.16.8.3`
  - NAT/Port-forward :
    - UDP 500 → 172.16.8.2
    - UDP 4500 → 172.16.8.2

- **StrongSwan**
  - IP publique : `51.159.83.52`
  - IP privée : `172.16.32.2/22`
  - LAN local : `172.16.32.0/22`

## Paramètres du tunnel

- Crypto IKE : `aes256-sha256-modp2048`, IKEv2
- Crypto ESP : `aes256-sha256`
- Authentification : PSK  
  `ko+alRLwBjRIVfca+1w5XpHr/1zCNMaWpZpsk15lD1w=`
- Proxy-ID / Subnets intéressés :
  - Local (Palo Alto) : `172.16.12.0/22`
  - Remote (StrongSwan) : `172.16.32.0/22`

## Étapes côté Palo Alto

1. Configurer les interfaces :
   - `ethernet1/1` = TRUST-ZONE, 172.16.12.2/22
   - `ethernet1/2` = UNTRUST-ZONE, 172.16.8.2/22

2. Créer les profils crypto `strongswan-ike` et `strongswan-ipsec`.

3. Créer l’IKE Gateway `GW-STRONGSWAN` :
   - Local address : `ethernet1/2`, IP `172.16.8.2/22`
   - Peer address : `51.159.83.52`
   - Local ID : `172.16.8.2`
   - PSK : clé partagée ci-dessus
   - NAT-T activé

4. Créer le tunnel IPsec `TUN-STRONGSWAN` sur `tunnel.1` avec le proxy-ID :
   - Local : `172.16.12.0/22`
   - Remote : `172.16.32.0/22`

5. Routage :
   - Default route 0.0.0.0/0 → `172.16.8.3` via `ethernet1/2`
   - Route `172.16.32.0/22` → interface `tunnel.1`

6. Règles de sécurité :
   - TRUST-ZONE → VPN-ZONE (allow)
   - VPN-ZONE → TRUST-ZONE (allow)

## Vérifications

- Côté Palo Alto :

```bash
> ping source 172.16.8.2 host 51.159.83.52
> show vpn ike-sa
> show vpn ipsec-sa
