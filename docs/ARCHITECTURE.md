# Architecture — what `docker compose up` actually does

![Architecture diagram](architecture.svg)

One command, `docker compose up -d`, reads `monitoring/docker-compose.yml` and
starts **five containers** (think: five tiny computers, each running one
program) wired together on a **private network** so they can talk to each
other by name.

## The flow, end to end

1. **PostgreSQL** starts first and runs `init.sql`, creating the mock retail
   tables (`stores`, `pos_transactions`, `sync_queue`) and seeding them — including
   one deliberately stale store so alerts have something real to fire on. A
   `healthcheck` holds everything else back until the database is ready.

2. **sql_exporter** waits for Postgres to be healthy (`depends_on`), then
   connects and runs the three operational SQL queries every few seconds,
   republishing the results as Prometheus-readable metrics on port `9399`.
   *This is the bridge from "monitor with SQL" to a standard metrics pipeline.*

3. **Prometheus** scrapes those metrics every 15s, stores them over time, and
   continuously evaluates the rules in `rules.yml` — e.g. *is any store's sync
   lag over 5 minutes? is the SLO error budget burning too fast?* When a rule
   matches, the alert flips to **FIRING**.

4. **Alertmanager** receives firing alerts from Prometheus and routes them by
   `severity` — `page` alerts go to the on-call path, `ticket` alerts to a
   lower-urgency channel. (In production this is where PagerDuty/Slack would
   plug in; here the routing itself is the proof.)

5. **Grafana** auto-loads its datasource and the "Retail Ops" dashboard from
   the `provisioning/` folder — no manual setup — and draws the panels by
   querying Prometheus, refreshing every 15s.

## Why containers find each other by name

Inside the Docker network (`monitoring_default`), Docker provides internal DNS,
so configs reference `postgres:5432` and `http://prometheus:9090` instead of IP
addresses. That's why the stack is portable: it works the same on any machine
without hardcoded addresses.

## The `-d` flag

`-d` = *detached*: run everything in the background so you get your terminal
back. Drop it (`docker compose up`) to watch all the logs stream live instead.

## Mental model in one line

> **`docker compose up` = start these five programs, each in its own box, on a
> shared network, in the right order, and keep them running.**

## Tearing down

```bash
docker compose down       # stop and remove the containers
docker compose down -v    # also wipe the database volume (fresh seed next boot)
```

Use `down -v` before a fresh `up` when you want the seeded sync-lag values to
reset — handy for a clean demo screenshot where store 4 is the lone outlier.
