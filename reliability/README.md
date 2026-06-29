# Reliability — on-call runbook automation

`diagnose.sh` is a first-responder for the three most common Kubernetes
incidents, aimed squarely at reducing rotating on-call toil.

```bash
./diagnose.sh <namespace> <deployment>            # read-only triage
./diagnose.sh prod pos-sync-worker --apply         # also takes safe action
```

| Scenario | Read-only output | With `--apply` |
|---|---|---|
| Stuck rollout | status + revision history | rollback to previous revision |
| CrashLoopBackOff | previous-container logs | delete pod for clean restart |
| Pending / unschedulable | scheduling events + likely cause | (none — needs human) |

Safety by design: no state changes unless `--apply` is passed.
