# 04 — Simulations and investigation workflow

## Run

On WS01, elevated PowerShell:

```powershell
cd C:\soc-homelab\simulations
.\Invoke-LabSimulation.ps1 -Scenario All      # or one scenario at a time
```

Every action is appended to `simulation-log-YYYYMMDD.csv` (UTC timestamps). That file is your **ground truth**: it tells you what really happened, so you can measure what your detections caught and what they missed. It is git-ignored.

| Scenario | ATT&CK | Expected rule(s) |
|---|---|---|
| Discovery | T1069.002, T1087.002 | 100122 |
| FailedLogons | T1110 | 100100 ×N, 100101 |
| NewLocalUser | T1136.001 | 100110 |
| PrivilegedGroup | T1098 | 100111 |
| EncodedPowerShell | T1059.001 | 100120 |
| ScheduledTask | T1053.005 | 100121 |
| RunKey | T1547.001 | 100130 |

## Investigate (the part that matters in interviews)

For each alert:

1. **Triage** — what fired, on which host, for which user, when? Severity?
2. **Scope** — filter the dashboard by the same host and a ±15 min window. What else happened? (Sysmon 1 parent/child processes, 4624 logons, 4104 script blocks.)
3. **Verdict** — true positive, false positive or benign true positive? Compare with the simulation log.
4. **Response** — what would you do in a real company? (disable account, isolate host, reset password, remove persistence, escalate to L2…)
5. **Improve** — was anything missed or noisy? Tune the rule and note it.

Then write it up with [`incidents/TEMPLATE.md`](../incidents/TEMPLATE.md).

## Clean up

```powershell
.\Invoke-LabSimulation.ps1 -Scenario Cleanup
```

Or revert WS01 to the `baseline-ready` snapshot.

## Coverage table (fill in after each run)

| Date | Scenario | Detected? | Rule | Time to alert | Notes / tuning |
|---|---|---|---|---|---|
| | | | | | |
