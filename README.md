# SOC Home Lab — Active Directory + Sysmon + Wazuh

A small, fully virtualised Security Operations Centre lab: a Windows Active Directory domain sends Sysmon and Windows Security telemetry to a Wazuh SIEM. I generate attacker-like activity, build detections mapped to **MITRE ATT&CK**, triage the alerts and write incident reports.

> Status: 🚧 in progress — see the checklist at the bottom.

## Why this lab

Junior SOC work is mostly: read logs, triage alerts, tell a true positive from a false one, and write it up clearly. This lab lets me practise all four end to end on infrastructure I built and control.

## Architecture

```
                 VirtualBox NAT Network "LabNet" 10.10.10.0/24 (gateway 10.10.10.1)
   ┌───────────────────────┬────────────────────────┬────────────────────────┐
   │                       │                        │                        │
┌──┴────────────────┐  ┌───┴───────────────────┐  ┌──┴─────────────────────┐
│ DC01              │  │ WS01                  │  │ WAZUH01                │
│ Windows Server    │  │ Windows 10/11         │  │ Ubuntu Server 24.04    │
│ AD DS + DNS       │  │ domain-joined client  │  │ Wazuh manager,         │
│ 10.10.10.10       │  │ 10.10.10.30           │  │ indexer, dashboard     │
│ Sysmon + agent    │  │ Sysmon + agent        │  │ 10.10.10.20            │
└───────────────────┘  └───────────────────────┘  └────────────────────────┘
          domain: lab.local          agents ──(1514/1515 TCP)──▶ manager
```

| VM | OS | vCPU | RAM | Disk |
|---|---|---|---|---|
| DC01 | Windows Server 2022 (evaluation) | 2 | 4 GB | 50 GB dynamic |
| WS01 | Windows 10/11 (evaluation) | 2 | 4 GB | 50 GB dynamic |
| WAZUH01 | Ubuntu Server 24.04 LTS | 4 | 8 GB | 50 GB dynamic |

Details: [docs/01-architecture.md](docs/01-architecture.md)

## What's inside

| Path | What it is |
|---|---|
| [`scripts/host/`](scripts/host) | Creates the VirtualBox NAT network from the host |
| [`scripts/dc/`](scripts/dc) | Promotes DC01, creates OUs/users/groups, enables advanced auditing |
| [`scripts/client/`](scripts/client) | Joins WS01 to the domain |
| [`scripts/common/`](scripts/common) | Installs Sysmon and the Wazuh agent, enables PowerShell logging |
| [`configs/sysmon/`](configs/sysmon) | My Sysmon configuration, tuned for this lab |
| [`configs/wazuh/`](configs/wazuh) | Agent log collection and **custom detection rules** (`local_rules.xml`) |
| [`simulations/`](simulations) | Harmless activity generator that triggers each detection |
| [`incidents/`](incidents) | Incident reports written from real alerts in this lab |
| [`docs/`](docs) | Build guide, detections, simulations |

## Detections

| Rule ID | Detection | ATT&CK | Level |
|---|---|---|---|
| 100101 | Multiple failed logons for the same account | T1110 Brute Force | 10 |
| 100110 | New user account created | T1136 Create Account | 8 |
| 100111 | Account added to a privileged group | T1098 Account Manipulation | 12 |
| 100120 | PowerShell launched with an encoded command | T1059.001 PowerShell | 10 |
| 100121 | Scheduled task created from the command line | T1053.005 Scheduled Task | 8 |
| 100122 | Domain admin / group discovery commands | T1069.002 Domain Groups | 5 |
| 100130 | Registry Run key persistence | T1547.001 Run Keys | 10 |

How each rule works and how I tested it: [docs/03-detections.md](docs/03-detections.md)

## Quick start

1. Follow the [build guide](docs/02-build-guide.md) (≈ 4–6 hours the first time).
2. Copy [`configs/wazuh/local_rules.xml`](configs/wazuh/local_rules.xml) to the manager and restart it.
3. On WS01 run `simulations\Invoke-LabSimulation.ps1 -Scenario All`, then `-Scenario Cleanup`.
4. Investigate the alerts in the Wazuh dashboard and write a report with [`incidents/TEMPLATE.md`](incidents/TEMPLATE.md).

## Safety

Everything here runs **only inside this isolated lab**. The simulations are benign (they run `whoami`, create and delete a test user, etc.) and each one has a cleanup step. Never point them at a network you don't own.

## Progress

- [ ] Network + 3 VMs built
- [ ] AD domain `lab.local` with users and groups
- [ ] Sysmon + Wazuh agent on DC01 and WS01
- [ ] Custom rules loaded and tested with `wazuh-logtest`
- [ ] All simulations trigger an alert
- [ ] 3+ incident reports written
- [ ] Architecture diagram + 3-minute video walkthrough

## Skills demonstrated

Active Directory · Windows Server · Sysmon · Wazuh (SIEM/XDR) · log analysis · detection engineering · MITRE ATT&CK · incident reporting · PowerShell · VirtualBox networking

## License

[MIT](LICENSE)
