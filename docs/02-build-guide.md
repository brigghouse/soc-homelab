# 02 — Build guide

Time: about 4–6 hours the first time (mostly waiting for installs). Host used: Windows 11, VirtualBox 7.2, 32 GB RAM.

Conventions: commands marked **[host]** run on the physical PC, **[DC01]**, **[WS01]** and **[WAZUH01]** inside each VM. All Windows commands run in an **elevated** PowerShell.

---

## Phase 0 — Downloads

| What | Where |
|---|---|
| Windows Server 2022 evaluation ISO (180 days) | Microsoft Evaluation Center |
| Windows 10/11 Enterprise evaluation ISO (90 days) — or reuse an existing Windows VM | Microsoft Evaluation Center |
| Ubuntu Server 24.04 LTS ISO | ubuntu.com/download/server |
| This repository | `git clone` onto the host; copy it into each Windows VM (shared folder or `git clone` inside the VM) |

> Evaluation editions are free and legal for labs. Take a VirtualBox **snapshot** after each phase so you can roll back instead of rebuilding.

## Phase 1 — Network [host]

```powershell
cd soc-homelab\scripts\host
.\New-LabNetwork.ps1
```

Creates NAT Network `LabNet` (10.10.10.0/24, DHCP off) and forwards `https://localhost:8443` → Wazuh dashboard.

For every VM: *Settings → Network → Adapter 1 → Attached to: NAT Network → Name: LabNet*.

## Phase 2 — DC01

1. New VM: Windows Server 2022, 2 vCPU, 4 GB RAM, 50 GB dynamic disk, adapter on `LabNet`.
2. Install *Windows Server 2022 Standard Evaluation (Desktop Experience)*. Set the local Administrator password.
3. Install VirtualBox Guest Additions (Devices → Insert Guest Additions CD) and reboot.
4. Copy the repo into the VM, then:

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
cd C:\soc-homelab\scripts\dc
.\01-Set-DCNetwork.ps1          # static IP 10.10.10.10, rename to DC01, reboots
.\02-Install-ADForest.ps1       # AD DS + DNS, forest lab.local, reboots
# log in as LAB\Administrator
.\03-New-LabObjects.ps1         # DNS forwarders, OUs, groups, 8 users
cd ..\common
.\Set-LabAuditPolicy.ps1
.\Enable-PowerShellLogging.ps1
```

Check: `Get-ADUser -Filter * | Select Name` lists the lab users; `nslookup google.com` works.

📸 Snapshot `DC01-ad-ready`.

## Phase 3 — WAZUH01

1. New VM: Ubuntu Server 24.04, 4 vCPU, 8 GB RAM, 50 GB disk, adapter on `LabNet`.
2. During install: static IP `10.10.10.20/24`, gateway `10.10.10.1`, DNS `10.10.10.10, 1.1.1.1`, enable OpenSSH.
3. Install Wazuh all-in-one. **Copy the current command from the Wazuh Quickstart page** (documentation.wazuh.com → Quickstart) so the version is current. It looks like:

```bash
curl -sO https://packages.wazuh.com/<major>.x/wazuh-install.sh
sudo bash ./wazuh-install.sh -a
```

4. Save the `admin` password the installer prints (store it in your password manager, **never** in this repo).
5. Note the version: `sudo /var/ossec/bin/wazuh-control info` → you need it for the agents.
6. Open `https://localhost:8443` on the host and log in.

📸 Snapshot `WAZUH01-installed`.

## Phase 4 — WS01

1. New VM (or clone/reuse an existing Windows 10/11 VM): 2 vCPU, 4 GB RAM, adapter on `LabNet`.
2. Copy the repo, then:

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
cd C:\soc-homelab\scripts\client
.\01-Join-LabDomain.ps1         # static IP 10.10.10.30, DNS -> DC01, join lab.local, reboots
# log in as LAB\Administrator (or a lab user)
cd ..\common
.\Set-LabAuditPolicy.ps1
.\Enable-PowerShellLogging.ps1
```

📸 Snapshot `WS01-joined`.

## Phase 5 — Telemetry (DC01 and WS01)

```powershell
cd C:\soc-homelab\scripts\common
.\Install-Sysmon.ps1
.\Install-WazuhAgent.ps1 -Version <manager version, e.g. 4.x.y>
```

Check in the dashboard: *Agents* shows DC01 and WS01 as **Active**. In *Discover* / *Threat Hunting*, filter `data.win.system.channel: "Microsoft-Windows-Sysmon/Operational"` → events appear.

## Phase 6 — Custom rules [WAZUH01]

```bash
sudo cp configs/wazuh/local_rules.xml /var/ossec/etc/rules/local_rules.xml
sudo chown wazuh:wazuh /var/ossec/etc/rules/local_rules.xml
sudo /var/ossec/bin/wazuh-analysisd -t      # must finish without errors
sudo systemctl restart wazuh-manager
```

(Copy the file with `scp` from the host or paste it with `nano`.)

📸 Snapshot everything: `baseline-ready`.

## Phase 7 — Simulate, detect, investigate [WS01]

```powershell
cd C:\soc-homelab\simulations
.\Invoke-LabSimulation.ps1 -Scenario All
```

Then follow [04-simulations.md](04-simulations.md) and write the reports in [`incidents/`](../incidents).

## Troubleshooting

| Symptom | Check |
|---|---|
| WS01 can't join the domain | `ping 10.10.10.10`, `nslookup lab.local` — DNS on WS01 must be 10.10.10.10 only |
| Kerberos / "time skew" errors | All VMs in the same time zone; `w32tm /resync` on WS01 |
| Agent "Never connected" | `Test-NetConnection 10.10.10.20 -Port 1514`; `C:\Program Files (x86)\ossec-agent\ossec.log` |
| No Sysmon events in Wazuh | `Get-Service Sysmon64`; the `<localfile>` block for Sysmon is in `ossec.conf`; restart `WazuhSvc` |
| Custom rule never fires | Find the raw event in Discover, check `rule.id` it matched and its `rule.groups`; adjust `if_group` (see [03-detections.md](03-detections.md)) |
| Dashboard not reachable | VM IP is 10.10.10.20; port forward exists: `VBoxManage natnetwork list` |
