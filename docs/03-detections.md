# 03 — Detections

All custom rules live in [`configs/wazuh/local_rules.xml`](../configs/wazuh/local_rules.xml). For each one: what it looks for, why it matters, how to trigger it, and known false positives.

## 100100 / 100101 — Failed logon burst (T1110 Brute Force)

- **Logic:** 100100 tags every 4625 (failed logon) and 4771 (Kerberos pre-auth failed). 100101 fires when the **same account** fails 8+ times in 120 s.
- **Why:** password guessing and spraying are among the most common initial-access techniques against AD.
- **Trigger:** `Invoke-LabSimulation.ps1 -Scenario FailedLogons`
- **False positives:** a user with an old saved password on a phone or mapped drive. Check the source host / IP and whether a successful 4624 follows.
- **Triage questions:** one account or many (spraying)? Which source? Did any attempt succeed afterwards? Was the account locked?

## 100110 — New user account (T1136 Create Account)

- **Logic:** event 4720.
- **Why:** attackers create accounts for persistence.
- **Trigger:** `-Scenario NewLocalUser`
- **False positives:** normal onboarding by the helpdesk. Compare with tickets and with who created it (`subjectUserName`).

## 100111 — Added to a privileged group (T1098 Account Manipulation)

- **Logic:** 4728/4732/4756 where the group is Domain Admins, Enterprise Admins, Schema Admins, Administrators, Account/Backup/Server Operators.
- **Why:** privilege escalation; few legitimate changes should happen here.
- **Trigger:** `-Scenario PrivilegedGroup`
- **False positives:** approved admin changes. Every one should match a change request.

## 100120 — PowerShell encoded command (T1059.001, T1027)

- **Logic:** Sysmon event 1 where the image is powershell/pwsh and the command line contains `-e`, `-ec`, `-enc…`, `-EncodedCommand` (or `/e`).
- **Why:** encoding hides the real command from casual inspection; widely used by malware droppers.
- **Trigger:** `-Scenario EncodedPowerShell`
- **Investigation tip:** decode the Base64 (UTF-16LE) or look at event **4104** (script block logging) on the same host and time — it shows the decoded code.
- **False positives:** some management tools (SCCM, some RMM agents) use encoded commands. Baseline and exclude by parent process.

## 100121 — Scheduled task via schtasks (T1053.005)

- **Logic:** Sysmon event 1, `schtasks.exe` with `/create`.
- **Trigger:** `-Scenario ScheduledTask` (Security event 4698 is also logged).
- **False positives:** software installers and IT scripts. Look at the task action (`/tr`) and the parent process.

## 100122 — Domain group / account discovery (T1069.002, T1087.002)

- **Logic:** Sysmon event 1, `net.exe`/`net1.exe` querying Domain/Enterprise Admins or `user/group … /domain`.
- **Why:** usually the first thing an intruder does after landing on a domain machine.
- **Trigger:** `-Scenario Discovery`
- **Level 5** on its own (admins do this); much more interesting when correlated with other alerts from the same user/host.

## 100130 — Registry Run key (T1547.001)

- **Logic:** Sysmon event 13 (registry value set) under `...\CurrentVersion\Run` or `RunOnce`.
- **Trigger:** `-Scenario RunKey`
- **False positives:** legitimate software adding itself to startup (OneDrive, Teams…). Check the binary path and its signature.

---

## Testing and troubleshooting a rule

1. Syntax: `sudo /var/ossec/bin/wazuh-analysisd -t`
2. Run the matching simulation scenario.
3. Watch alerts live on WAZUH01:
   ```bash
   sudo tail -f /var/ossec/logs/alerts/alerts.json | grep -E '"id":"1001[0-9]{2}"'
   ```
4. If nothing appears: find the raw event in the dashboard (it is still stored even if it matched a default rule). Look at `rule.id` and `rule.groups`. My rules hang off the groups `windows`, `sysmon` and `sysmon_event1` of the default ruleset; if your Wazuh version names them differently, change the `<if_group>` (or use `<if_sid>` with the parent rule ID you saw) and re-test.
5. Record what you changed and why in the commit message — that history is part of the portfolio.
