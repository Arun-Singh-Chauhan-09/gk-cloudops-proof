# Monitoring — POS health & SLO observability

The centerpiece. A complete, runnable observability stack that turns
operational SQL questions into Prometheus metrics, visualises them in Grafana,
and pages on-call only when an SLO error budget is genuinely burning.

## Run it
```bash
docker compose up -d
```
- **Grafana** http://localhost:3000 (admin/admin) → "Retail Ops — POS Health & SLO"
- **Prometheus** http://localhost:9090 → Alerts / Rules tabs
- **Alertmanager** http://localhost:9093

## How it fits together
```
postgres (mock POS data)
   └─> sql_exporter   reads operational SQL  -> exposes Prometheus metrics
          └─> prometheus   scrapes + evaluates SLO burn-rate rules
                 ├─> alertmanager   routes page vs ticket
                 └─> grafana        auto-provisioned dashboard
```

## The metrics (from `sql-exporter/sql_exporter.yml`)
| Metric | Operational question | Drives |
|---|---|---|
| `pos_transactions_total{status}` | Are checkouts succeeding? | Success-rate SLO |
| `store_sync_lag_seconds{store_id,region}` | Is any store going stale? | Freshness page |
| `sync_queue_backlog{store_id}` | Is replication falling behind? | Backlog ticket + KEDA scaling |

## Why burn-rate alerting
`prometheus/rules.yml` implements the Google SRE multi-window method: a fast
(1h) and slow (6h) window must **both** breach before paging. This suppresses
transient spikes that would otherwise wake on-call for nothing, while still
catching sustained budget burn quickly. SLO target: 99.9% POS success.
