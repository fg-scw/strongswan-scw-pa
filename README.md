# Palo Alto ↔ StrongSwan – IPsec Site-to-Site (Scaleway)

##  High-level Diagram

```mermaid
graph LR
  subgraph INTERNET["Internet Public"]
    PA_PUB["PA: 51.159.83.78"]
    SS_PUB["StrongSwan: 51.159.83.52"]
  end

  subgraph VPC1_UNTRUST["VPC 1 - UNTRUST"]
    UNTRUST_NET["172.16.8.0/22"]
    NATGW["Public Gateway<br/>51.159.162.39<br/>172.16.8.3/22<br/>NAT-T: UDP 500/4500"]
    PA_UNTRUST["PA UNTRUST<br/>172.16.8.2/22"]
  end

  subgraph VPC1_TRUST["VPC 1 - TRUST"]
    TRUST_NET["172.16.12.0/22"]
    PA_TRUST["PA TRUST<br/>172.16.12.2/22"]
  end

  subgraph VPC2["VPC 2 - StrongSwan"]
    LAN2["172.16.32.0/22"]
    SS["StrongSwan VM<br/>51.159.83.52<br/>172.16.32.2/22"]
  end

  TRUST_NET --- PA_TRUST
  PA_TRUST -->|Tunnel Encrypted| PA_UNTRUST
  PA_UNTRUST --- UNTRUST_NET
  UNTRUST_NET --- NATGW
  NATGW -->|NAT-T<br/>UDP 500/4500| SS_PUB
  SS_PUB -.->|IPsec Tunnel| PA_PUB
  SS --- LAN2

  style INTERNET fill:#1e3a5f,stroke:#4a9eff,stroke-width:2px,color:#fff
  style VPC1_UNTRUST fill:#2d5016,stroke:#7ec850,stroke-width:2px,color:#fff
  style VPC1_TRUST fill:#3d2061,stroke:#a78bfa,stroke-width:2px,color:#fff
  style VPC2 fill:#1f4d5c,stroke:#4db8cc,stroke-width:2px,color:#fff
 ``` 
---
```
---

##  Files in this repository

- `palo-alto.conf` – CLI configuration snippet for the Palo Alto VM-Series  
  (interfaces, zones, IKE gateway, IPsec tunnel, routes, security rules).
- `scw-stgswan.sh` – StrongSwan installation & configuration script  
  (installs strongSwan, configures `ipsec.conf` and `ipsec.secrets`).

---

##  Addresses & Roles (reference)

**Palo Alto VM-Series (VPC1)**  
- TRUST (LAN) : `172.16.12.2/22` → `172.16.12.0/22`  
- UNTRUST : `172.16.8.2/22` (vers NAT GW `172.16.8.3`)  

**NAT Gateway (VPC1)**  
- Publique : `51.159.162.39`  
- Privée : `172.16.8.3/22`  
- Port forwarding obligatoire :
  - UDP `500` → `172.16.8.2`
  - UDP `4500` → `172.16.8.2`

**StrongSwan (VPC2)**  
- Publique : `51.159.83.52`  
- Privée : `172.16.32.2/22` → `172.16.32.0/22`

---

##  IPsec Parameters (shared)

- IKE version : **IKEv2**
- IKE crypto : `aes256-sha256-modp2048`
- ESP crypto : `aes256-sha256`
- PSK (example used in this lab):

  ```text
  ko+alRLwBjRIVfca+1w5XpHr/1zCNMaWpZpsk15lD1w=
  ```

- Protected subnets:
  - Palo Alto side : `172.16.12.0/22`
  - StrongSwan side : `172.16.32.0/22`

---

##  Usage

### 1. Palo Alto

1. Connect to the Palo Alto CLI.
2. Load/apply the configuration from **`palo-alto.conf`**  
   (adapt interfaces, zones, IPs, and PSK if needed).
3. Commit and verify:

   ```bash
   > show vpn ike-sa
   > show vpn ipsec-sa
   > show routing route
   ```

### 2. StrongSwan VM (Ubuntu/Debian)

1. Copy **`scw-stgswan.sh`** to the StrongSwan VM.
2. Make it executable and run it:

   ```bash
   chmod +x scw-stgswan.sh
   sudo ./scw-stgswan.sh
   ```

3. Check the tunnel status:

   ```bash
   ipsec statusall
   ```

If both sides are correctly configured, you should see an **ESTABLISHED** IKE SA and be able to reach:

- From Palo Alto LAN (`172.16.12.0/22`) → `172.16.32.0/22`
- From StrongSwan LAN (`172.16.32.0/22`) → `172.16.12.0/22`
