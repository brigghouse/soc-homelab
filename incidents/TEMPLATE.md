# INC-XXX — <short title, e.g. "Password guessing against hprice from WS01">

| Field | Value |
|---|---|
| Date (UTC) | YYYY-MM-DD HH:MM |
| Analyst | <your name> |
| Severity | Low / Medium / High / Critical |
| Status | Open / Closed |
| Verdict | True positive / False positive / Benign true positive |
| Hosts | WS01, DC01 |
| Accounts | LAB\... |
| MITRE ATT&CK | Txxxx — <name> |
| Wazuh rule(s) | 1001xx |

## 1. Summary
Two or three sentences a manager could read: what happened, impact, what was done.

## 2. Detection
- Alert that fired (rule ID, level, description) and when.
- Screenshot of the alert: `![alert](img/INC-XXX-alert.png)`

## 3. Investigation

### Timeline (UTC)
| Time | Host | Source (log / event ID) | What happened |
|---|---|---|---|
| | | | |

### Evidence
- Relevant fields (user, process, command line, parent process, source IP…).
- Query used in the dashboard, e.g. `agent.name:WS01 and data.win.system.eventID:4625`
- Indicators: accounts, hashes, registry keys, task names…

### Analysis
How you reached the verdict. What made it suspicious, what ruled out a false positive.

## 4. Containment and remediation
What you did (or would do in production): disable/reset account, remove persistence, isolate host, block source…

## 5. Lessons learned
- Detection gaps or noise found.
- Rule tuning made (link to the commit).
- What you would add next (new log source, new rule).
