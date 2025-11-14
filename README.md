# Palo Alto ↔ StrongSwan – IPsec Site-to-Site (Scaleway)

##  High-level Diagram
```mermaid
graph TB
  subgraph ORG1["ORGANISATION 1 - Scaleway VPC"]
    subgraph PGW_GROUP["Public Gateway"]
      PGW["51.159.162.39"]
    end
    
    subgraph UNTRUST["Private Network UNTRUST<br/>172.16.8.0/22"]
      PA_UNTRUST["PA VM-Series<br/>172.16.8.2"]
    end
    
    subgraph TRUST["Private Network TRUST<br/>172.16.12.0/22"]
      PA_TRUST["PA VM-Series<br/>172.16.12.2"]
      VMS1["VMs / Services<br/>172.16.12.x"]
    end
    
    PGW ---|NAT-T UDP 500/4500| PA_UNTRUST
    PA_UNTRUST ---|Tunnel| PA_TRUST
    PA_TRUST --- VMS1
  end

  subgraph ORG2["ORGANISATION 2 - Scaleway VPC"]
    subgraph SS_GROUP["StrongSwan VM"]
      SS_PUB["51.159.83.52"]
      SS_PRIV["172.16.32.2"]
    end
    
    subgraph LAN2["Private Network LAN<br/>172.16.32.0/22"]
      VMS2["VMs / Services<br/>172.16.32.x"]
    end
    
    SS_PRIV --- VMS2
  end

  subgraph INTERNET["Internet"]
    INET["Public IPs"]
  end

  VMS2 -->|172.16.32.0/22| SS_PRIV
  SS_PRIV -->|Encapsulation IPsec| SS_PUB
  SS_PUB -.->|UDP 500/4500 NAT-T| PGW
  PGW -->|Port Forward| PA_UNTRUST
  PA_UNTRUST -->|IPsec Tunnel<br/>172.16.12.0/22 ↔ 172.16.32.0/22| PA_TRUST
  PA_TRUST -->|172.16.12.0/22| VMS1

  SS_PUB --> INET
  PGW --> INET

  style ORG1 fill:#0f172a,stroke:#60a5fa,stroke-width:3px,color:#e0e7ff
  style ORG2 fill:#0f172a,stroke:#34d399,stroke-width:3px,color:#e0e7ff
  style INTERNET fill:#0f172a,stroke:#fbbf24,stroke-width:2px,color:#e0e7ff
  style PGW_GROUP fill:#1e293b,stroke:#60a5fa,stroke-width:2px,color:#e0e7ff
  style SS_GROUP fill:#1e293b,stroke:#34d399,stroke-width:2px,color:#e0e7ff
  style UNTRUST fill:#1e293b,stroke:#60a5fa,stroke-width:2px,color:#e0e7ff
  style TRUST fill:#1e293b,stroke:#a78bfa,stroke-width:2px,color:#e0e7ff
  style LAN2 fill:#1e293b,stroke:#34d399,stroke-width:2px,color:#e0e7ff
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
