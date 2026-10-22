# 01 — Architecture

## Network

| Item | Value |
|---|---|
| VirtualBox network | NAT Network `LabNet` |
| Subnet | `10.10.10.0/24` |
| Gateway (VirtualBox) | `10.10.10.1` |
| DHCP | Off — every VM has a static IP |
| DNS for domain members | `10.10.10.10` (DC01) |
| DNS forwarder on DC01 | `1.1.1.1`, `8.8.8.8` |

A NAT Network keeps the VMs on their own subnet, lets them talk to each other, and still gives them internet access for downloads and updates. Nothing on my home network can reach them without explicit port forwarding.

## Hosts

| Host | IP | Role | Logs sent to Wazuh |
|---|---|---|---|
| DC01 | 10.10.10.10 | Domain controller, DNS | Security, System, Sysmon, PowerShell |
| WS01 | 10.10.10.30 | Domain-joined workstation (where simulations run) | Security, System, Sysmon, PowerShell |
| WAZUH01 | 10.10.10.20 | Wazuh manager + indexer + dashboard | — |

## Active Directory

- Domain: `lab.local` (NetBIOS `LAB`)
- OU layout:

```
lab.local
└── LAB
    ├── Users
    │   ├── IT
    │   ├── Finance
    │   └── Sales
    ├── Workstations
    ├── Servers
    ├── Groups
    └── Disabled
```

- Users and groups come from [`scripts/dc/lab-users.csv`](../scripts/dc/lab-users.csv). All are fictional.

## Telemetry

| Source | Why |
|---|---|
| Security log (with advanced audit policy) | Logons (4624/4625), account changes (4720, 4728, 4732, 4756), scheduled tasks (4698) |
| Sysmon | Process creation with full command lines (1), network connections (3), process access (10), file creation (11), registry changes (12/13) |
| PowerShell Operational | Script block logging (4104) shows what PowerShell actually ran, even if encoded |

## Ports

| From | To | Port | Purpose |
|---|---|---|---|
| Agents | WAZUH01 | 1514/TCP | Event forwarding |
| Agents | WAZUH01 | 1515/TCP | Agent enrolment |
| Host browser | WAZUH01 | 443/TCP (via port forward 8443) | Wazuh dashboard |

## Resource budget (host: 32 GB RAM, i7-14650HX)

| VM | RAM | Disk actually used (approx.) |
|---|---|---|
| DC01 | 4 GB | ~20 GB |
| WS01 | 4 GB | ~25 GB |
| WAZUH01 | 8 GB | ~15–20 GB |
| **Total** | **16 GB** | **~60–65 GB** |
