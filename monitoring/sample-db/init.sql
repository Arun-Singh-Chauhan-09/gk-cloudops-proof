-- ============================================================================
-- Mock retail / POS schema for a CLOUD4RETAIL-style platform.
-- Purpose: give sql_exporter realistic tables to derive operational metrics
-- from, so Prometheus/Grafana/Alertmanager have live signals to act on.
--
-- This is illustrative data modelling, NOT GK's real schema. It mirrors the
-- shape of problems an operations team faces: store sync lag, failed POS
-- transactions, and replication queue depth.
-- ============================================================================

CREATE TABLE IF NOT EXISTS stores (
    store_id      INT PRIMARY KEY,
    region        TEXT NOT NULL,
    last_sync_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS pos_transactions (
    txn_id        BIGSERIAL PRIMARY KEY,
    store_id      INT NOT NULL REFERENCES stores(store_id),
    status        TEXT NOT NULL CHECK (status IN ('success','failed','pending')),
    amount_cents  INT NOT NULL,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Replication / outbound sync queue: depth here is a classic SLO signal.
CREATE TABLE IF NOT EXISTS sync_queue (
    item_id       BIGSERIAL PRIMARY KEY,
    store_id      INT NOT NULL REFERENCES stores(store_id),
    enqueued_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    processed     BOOLEAN NOT NULL DEFAULT false
);

-- ---------------------------------------------------------------------------
-- Seed data
-- ---------------------------------------------------------------------------
INSERT INTO stores (store_id, region, last_sync_at) VALUES
    (1, 'eu-central',  now() - interval '30 seconds'),
    (2, 'eu-central',  now() - interval '2 minutes'),
    (3, 'eu-west',     now() - interval '45 seconds'),
    (4, 'us-east',     now() - interval '12 minutes'),   -- intentionally stale -> should alert
    (5, 'ap-southeast',now() - interval '1 minute')
ON CONFLICT (store_id) DO NOTHING;

-- Generate ~2000 transactions over the last hour, ~3% failures.
INSERT INTO pos_transactions (store_id, status, amount_cents, created_at)
SELECT
    (1 + floor(random() * 5))::int,
    CASE WHEN random() < 0.03 THEN 'failed'
         WHEN random() < 0.05 THEN 'pending'
         ELSE 'success' END,
    (100 + floor(random() * 9900))::int,
    now() - (random() * interval '60 minutes')
FROM generate_series(1, 2000);

-- A backlog in the sync queue for the stale store.
INSERT INTO sync_queue (store_id, enqueued_at, processed)
SELECT 4, now() - (random() * interval '15 minutes'), false
FROM generate_series(1, 240);

INSERT INTO sync_queue (store_id, enqueued_at, processed)
SELECT (1 + floor(random() * 3))::int, now() - (random() * interval '5 minutes'), true
FROM generate_series(1, 500);
