# Cost — right-sizing & demand-driven scaling

Three complementary levers against the biggest source of silent cloud spend in
a multi-instance SaaS: capacity that's provisioned once and never revisited.

## 1. Right-sizing analyzer — `rightsizer.py`
Compares CPU/memory *requests* vs observed *usage* and flags workloads where
both are under-utilised, with a suggested request and estimated monthly saving.
```bash
python3 rightsizer.py --input sample_usage.json
python3 rightsizer.py --input sample_usage.json --threshold 0.3
```
Only flags a workload when **both** CPU and memory are under threshold, so it
won't starve a memory-bound service by trimming its CPU.

## 2. Off-hours scaling — `offhours-scaler.yaml`
Two CronJobs scale non-prod deployments to zero overnight/weekends and restore
them in the morning, storing prior replica counts in an annotation. This is the
Kubernetes-native form of the scheduled-shutdown approach that delivered a
~35% AWS reduction in a prior role. RBAC scoped to the `nonprod` namespace.

## 3. Demand-driven autoscaling — `keda-scaledobject.yaml`
KEDA scales the POS sync worker on the live `sync_queue_backlog` metric
(exported by the monitoring stack), scaling to zero when idle. Capacity tracks
real backlog instead of a fixed replica count.
