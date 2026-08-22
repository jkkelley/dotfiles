---
name: dba
description: >-
  Database design advisor covering schema modeling, normalization vs denormalization
  trade-offs, single-table vs multi-table decisions, indexing, query optimization,
  and migration patterns across PostgreSQL, MySQL, and SQLite. Use when designing
  schemas, evaluating table structure, writing migrations, choosing between join
  tables or embedded columns, asking about indexes, or any relational database
  design question. Preloaded into the backend-dev agent.
version: 1.0.1
---

# DBA — Database Design Advisor

> **This copy is read-only.**
> Skills are vendored into a project as copies, and this may be one.
> Edit this skill at `~/dotfiles/claude/skills/dba/`, bump its version, then re-pull it - never edit the copy where it landed.
> `skill-update.sh` replaces the skill's directory rather than merging into it, so a local edit is destroyed by the next update with no conflict and no warning.
> The registry's content hash cannot catch it either, because a project's copy legitimately differs from upstream.

## Schema Design Workflow

When designing or reviewing a schema, work through this sequence:

1. **Identify entities and their cardinality** — 1:1, 1:N, M:N
2. **Choose a normalization target** — 3NF as default; relax with clear justification
3. **Decide table boundaries** — each table owns one concept
4. **Pick primary key strategy** — surrogate vs natural (see below)
5. **Add constraints before indexes** — constraints are guarantees; indexes are hints
6. **Design indexes around query patterns** — index after you know the reads

---

## Primary Key Strategies

| Strategy | When to use | Trade-off |
|----------|-------------|-----------|
| `BIGINT GENERATED ALWAYS AS IDENTITY` | Default for most tables | No portability outside DB |
| `UUID v4` | Distributed systems, client-generated IDs | Larger, random — hurts clustered index locality |
| `UUID v7` | UUID + time-ordered | Best of both: globally unique + sorted |
| Natural key | Truly stable, unique business value (e.g. ISO country code) | Brittle if business rules change |

**Default recommendation:** `BIGINT` surrogate for internal tables; `UUID v7` for public-facing APIs or distributed writes.

---

## Normalization vs Denormalization

### Normalize when:
- Write-heavy workloads (updates touch one place)
- Data integrity is critical (billing, inventory, medical)
- Schema evolves frequently
- Row counts are large (duplication cost compounds)

### Denormalize when:
- Read-heavy, analytical, or reporting workloads
- Join cost is measured and painful (benchmark first)
- The field is truly immutable at copy time (e.g. `order_snapshot_json`)
- Building a cache or read model (CQRS)

**Anti-pattern:** Denormalizing preemptively without a query profile. Always measure before flattening.

---

## Single Table vs Multiple Tables

### Use **fewer, wider tables** when:
- Data always travels together (low fan-out queries)
- The relationship is 1:1 and always present
- You control the schema end-to-end (no external consumers)
- Simplicity is higher priority than extensibility

```sql
-- Good: user profile always loaded with user
ALTER TABLE users ADD COLUMN bio TEXT, ADD COLUMN avatar_url TEXT;
```

### Use **more, focused tables** when:
- Optional attributes (NULL-heavy wide tables are a smell)
- The entity type varies (polymorphism, inheritance)
- Sub-tables have independent lifecycles or owners
- You need fine-grained permissions or audit trails

```sql
-- Good: profile is optional, loaded separately
CREATE TABLE user_profiles (
  user_id BIGINT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  bio     TEXT,
  avatar_url TEXT
);
```

### Junction / bridge tables (M:N)

Always use an explicit join table with its own surrogate key and metadata:

```sql
CREATE TABLE user_roles (
  id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id    BIGINT NOT NULL REFERENCES users(id)  ON DELETE CASCADE,
  role_id    BIGINT NOT NULL REFERENCES roles(id)  ON DELETE CASCADE,
  granted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  granted_by BIGINT REFERENCES users(id),
  UNIQUE (user_id, role_id)
);
```

---

## Indexing

### Rules of thumb
- Every foreign key should have an index (unless writes dominate and it's never joined)
- Composite indexes: **selectivity descending**, unless range scan forces otherwise
- Covering indexes eliminate heap fetches — include non-filter columns with `INCLUDE`
- Partial indexes narrow index size for filtered queries

```sql
-- Partial index: only active users need fast lookup
CREATE INDEX idx_users_email_active ON users(email) WHERE deleted_at IS NULL;

-- Covering index: avoids heap fetch for name + email lookups
CREATE INDEX idx_users_name ON users(last_name, first_name) INCLUDE (email);

-- Composite: filter on status first (low cardinality but heavily filtered)
CREATE INDEX idx_orders_status_created ON orders(status, created_at DESC);
```

### Index smell signals
- `EXPLAIN ANALYZE` shows `Seq Scan` on large tables
- Slow `WHERE col IS NULL` or `WHERE col IS NOT NULL`
- Slow `ORDER BY` without matching index direction

---

## Constraints

Declare constraints in the schema, not only in application code:

```sql
-- Nullable only when truly optional
ALTER TABLE orders ADD COLUMN cancelled_at TIMESTAMPTZ;

-- Always constrain ranges at DB level
ALTER TABLE products ADD CONSTRAINT chk_price_positive CHECK (price_cents > 0);

-- Use enum-as-text + check over DB enum types (easier to migrate)
ALTER TABLE orders ADD CONSTRAINT chk_status
  CHECK (status IN ('pending','paid','shipped','cancelled'));
```

---

## Soft Deletes

```sql
-- Add to any table that needs soft delete
ALTER TABLE resources ADD COLUMN deleted_at TIMESTAMPTZ;

-- Partial index so queries stay fast
CREATE INDEX idx_resources_active ON resources(id) WHERE deleted_at IS NULL;

-- Always filter in queries
SELECT * FROM resources WHERE deleted_at IS NULL;
```

**Trade-off:** Soft deletes complicate unique constraints. Use conditional unique indexes:

```sql
CREATE UNIQUE INDEX idx_users_email_unique
  ON users(email) WHERE deleted_at IS NULL;
```

---

## Audit / History Patterns

### Option A — Trigger-based shadow table
Good for complete, automatic capture; adds write overhead.

### Option B — Application-level event log
Good for semantic events ("user changed billing address"); requires discipline.

### Option C — Temporal tables (PostgreSQL with `temporal_tables` or SQL:2011)
Good for point-in-time queries; complex to query.

**Default:** Start with a simple `audit_log` event table, add shadow tables only for regulated data.

```sql
CREATE TABLE audit_log (
  id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  table_name  TEXT NOT NULL,
  record_id   BIGINT NOT NULL,
  action      TEXT NOT NULL CHECK (action IN ('INSERT','UPDATE','DELETE')),
  old_data    JSONB,
  new_data    JSONB,
  actor_id    BIGINT REFERENCES users(id),
  occurred_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

---

## Migrations

- **Always reversible** — write both `up` and `down`
- **Non-blocking adds**: adding a nullable column is instant; adding NOT NULL is not
- **Backfill separately** from constraint addition on large tables
- **Never rename a column** in a single step in production — add new, backfill, swap, drop old

```sql
-- Safe: add nullable first
ALTER TABLE users ADD COLUMN phone TEXT;

-- Safe later: backfill in batches, then add constraint
ALTER TABLE users ALTER COLUMN phone SET NOT NULL;
```

---

## Common Table Trade-off Checklist

When deciding whether to split or merge:

- [ ] Will these columns always be queried together? → merge
- [ ] Can a row exist without these columns? → split (or nullable + 1:1)
- [ ] Does this entity have its own lifecycle? → split
- [ ] Will this grow to millions of rows independently? → split
- [ ] Is this a cache or read projection? → separate table or materialized view
- [ ] Do different roles own different parts of this data? → split

---

## Reference

For deeper dives see [reference.md](reference.md) — covering:
- Inheritance patterns (STI vs CTI vs JSON)
- Sharding and partitioning
- Connection pooling (PgBouncer)
- JSONB vs relational column trade-offs
- Full-text search setup
