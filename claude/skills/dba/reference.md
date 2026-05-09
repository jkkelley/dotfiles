# DBA Reference — Deep Dive

## Table Inheritance Patterns

### Single Table Inheritance (STI)
One table holds all subtypes; subtype discriminator column selects rows.

```sql
CREATE TABLE notifications (
  id      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  kind    TEXT NOT NULL CHECK (kind IN ('email','sms','push')),
  user_id BIGINT NOT NULL REFERENCES users(id),
  -- email-only columns
  subject TEXT,
  -- sms-only columns
  phone   TEXT,
  -- push-only columns
  device_token TEXT,
  sent_at TIMESTAMPTZ
);
```

**Pros:** simple queries, no joins  
**Cons:** NULL columns, wide tables, CHECK constraint lists grow with subtypes

**Use when:** subtypes share most columns; few subtypes; query patterns always span types.

---

### Class Table Inheritance (CTI / Concrete Table)
Base table + one table per subtype, joined on PK.

```sql
CREATE TABLE notifications (
  id      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  kind    TEXT NOT NULL,
  user_id BIGINT NOT NULL REFERENCES users(id),
  sent_at TIMESTAMPTZ
);

CREATE TABLE email_notifications (
  notification_id BIGINT PRIMARY KEY REFERENCES notifications(id) ON DELETE CASCADE,
  subject TEXT NOT NULL,
  body    TEXT NOT NULL
);

CREATE TABLE sms_notifications (
  notification_id BIGINT PRIMARY KEY REFERENCES notifications(id) ON DELETE CASCADE,
  phone   TEXT NOT NULL,
  message TEXT NOT NULL
);
```

**Pros:** no NULLs, each subtype table is narrow, clean constraints  
**Cons:** every query needs a join; polymorphic queries require UNION or a view

**Use when:** subtypes diverge significantly; each subtype is queried independently.

---

### JSONB for Flexible Attributes

```sql
CREATE TABLE events (
  id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  kind       TEXT NOT NULL,
  payload    JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index a specific JSON key
CREATE INDEX idx_events_payload_user ON events ((payload->>'user_id'));
```

**Pros:** schema-less extension; good for event sourcing, feature flags, sparse attributes  
**Cons:** no referential integrity inside JSONB; queries are verbose; type coercion required

**Rule:** use JSONB for truly open-ended or rapidly evolving attributes. For known attributes, use columns.

---

## Partitioning

### Range Partitioning (time-series data)

```sql
CREATE TABLE events (
  id         BIGINT NOT NULL,
  occurred_at TIMESTAMPTZ NOT NULL,
  payload    JSONB
) PARTITION BY RANGE (occurred_at);

CREATE TABLE events_2025 PARTITION OF events
  FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');

CREATE TABLE events_2026 PARTITION OF events
  FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
```

**When to partition:** table exceeds ~50–100 M rows; most queries filter on the partition key; old partitions can be dropped or archived.

### Hash Partitioning (distribute writes)

```sql
CREATE TABLE sessions (
  id      UUID NOT NULL,
  user_id BIGINT NOT NULL,
  data    JSONB
) PARTITION BY HASH (id);

CREATE TABLE sessions_0 PARTITION OF sessions FOR VALUES WITH (MODULUS 4, REMAINDER 0);
-- ... sessions_1, sessions_2, sessions_3
```

---

## Connection Pooling (PgBouncer)

| Mode | How it works | Best for |
|------|-------------|----------|
| Session | 1 DB conn per client session | Long-lived, stateful connections |
| Transaction | 1 DB conn per transaction | Short transactions (APIs, web) |
| Statement | 1 DB conn per statement | Read-only, simple queries only |

**Default for web apps:** Transaction mode with pool size = `num_cores * 2 + disk_count`.

**Caveats in transaction mode:** `SET LOCAL`, advisory locks, `LISTEN/NOTIFY`, and prepared statements need special handling.

---

## JSONB vs Relational Column

| Criterion | Relational column | JSONB |
|-----------|------------------|-------|
| Query performance | Fast (indexed) | Slower unless key-indexed |
| Referential integrity | Enforced by DB | Not enforced |
| Schema evolution | Requires migration | Schema-free |
| Type safety | Strong | Weak (all values are text/number/bool/null) |
| Aggregations / reporting | Straightforward | Requires `jsonb_to_recordset` or similar |

**Decision rule:** if you query or filter on the field more than a few times a week → relational column. If it's arbitrary metadata that varies per record → JSONB.

---

## Full-Text Search (PostgreSQL)

```sql
-- Add a generated tsvector column (auto-updated)
ALTER TABLE articles ADD COLUMN search_vector TSVECTOR
  GENERATED ALWAYS AS (
    to_tsvector('english', coalesce(title, '') || ' ' || coalesce(body, ''))
  ) STORED;

CREATE INDEX idx_articles_fts ON articles USING GIN (search_vector);

-- Query
SELECT id, title
FROM articles
WHERE search_vector @@ plainto_tsquery('english', 'database design')
ORDER BY ts_rank(search_vector, plainto_tsquery('english', 'database design')) DESC;
```

**When to reach for Elasticsearch/OpenSearch instead:** faceted search, fuzzy matching, synonyms, relevance tuning, cross-index joins.

---

## Sharding Strategies

| Strategy | Description | Pros | Cons |
|----------|-------------|------|------|
| Application-level | App routes to shard based on key | Full control | Complex app code |
| Citus (PostgreSQL) | Distributed PG with shard-aware planner | Transparent SQL | Operational overhead |
| Read replicas | Route reads to replica(s) | Easy wins | Replication lag; no write scale |
| Functional sharding | Split by domain (users DB, orders DB) | Team ownership, isolation | Cross-shard joins impossible |

**Start here:** read replicas → connection pooling → vertical scaling → partitioning → functional sharding → horizontal sharding. Each step buys significant headroom before the next.

---

## N+1 and Query Pattern Checklist

- [ ] ORMs: use eager loading (`JOIN` or `IN`) instead of lazy-loading in loops
- [ ] Paginate with keyset pagination (cursor-based), not `OFFSET` — OFFSET scans all skipped rows
- [ ] Batch inserts: use `INSERT ... VALUES (row1), (row2), ...` not one insert per row
- [ ] Use `RETURNING id` to avoid a second round-trip after insert
- [ ] `EXPLAIN (ANALYZE, BUFFERS)` before optimizing — never guess
- [ ] Track `pg_stat_statements` in production to find real slow queries
