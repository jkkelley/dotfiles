---
name: backend-patterns
description: Backend development patterns covering API conventions, error handling, database, caching, and resilience. Preloaded into the backend-dev agent.
---

# Backend Patterns

## API Response Conventions

```json
// Success — single resource
{ "data": { "id": "user-123", "email": "alice@example.com" } }

// Success — collection with pagination
{
  "data": [...],
  "pagination": {
    "next_cursor": "eyJpZCI6MTIzfQ==",
    "has_more": true,
    "total": 847
  }
}

// Error envelope — always consistent
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Request validation failed",
    "details": [
      { "field": "email", "message": "Invalid email format" }
    ],
    "request_id": "req_01HXYZ",
    "documentation_url": "https://docs.example.com/errors/VALIDATION_ERROR"
  }
}
```

**HTTP Status Codes:**
```
200 OK              — GET success, PUT/PATCH success (returns body)
201 Created         — POST success (returns created resource)
204 No Content      — DELETE success, PUT with no body
400 Bad Request     — malformed request, invalid params
401 Unauthorized    — not authenticated (missing/invalid token)
403 Forbidden       — authenticated but not authorized
404 Not Found       — resource doesn't exist
409 Conflict        — duplicate, version conflict, state conflict
422 Unprocessable   — valid format, invalid business logic
429 Too Many Req    — rate limited (include Retry-After header)
500 Internal Error  — unexpected server error (don't leak details)
503 Unavailable     — overloaded, starting up, circuit open
```

## Database Patterns

```python
# N+1 — the most common backend bug
# WRONG: N queries
posts = Post.query.all()
for post in posts:
    comments = Comment.query.filter_by(post_id=post.id).all()

# RIGHT: 1 query with eager load
posts = Post.query.options(joinedload(Post.comments)).all()

# Batch insert (not one-by-one)
db.session.bulk_save_objects(records)
db.session.commit()

# Cursor-based pagination (stable under inserts)
async def list_orders(cursor: str | None, limit: int = 50):
    query = Order.query.order_by(Order.id)
    if cursor:
        query = query.filter(Order.id > decode_cursor(cursor))
    rows = query.limit(limit + 1).all()
    has_more = len(rows) > limit
    return rows[:limit], make_cursor(rows[limit - 1].id) if has_more else None
```

**Schema Migration Safety (never destructive immediately):**
```
Step 1: Add new_column (nullable) → deploy → app writes both old + new
Step 2: Backfill new_column from old_column (batched, off-peak)
Step 3: Add NOT NULL constraint → deploy → reads use new_column only
Step 4: Drop old_column (safe now)
```

## Caching Patterns

```python
# Cache-aside (most common)
async def get_user(user_id: str) -> User:
    key = f"user:{user_id}"
    if cached := await redis.get(key):
        return User.parse_raw(cached)
    user = await db.fetch_user(user_id)
    await redis.setex(key, 300, user.json())  # 5 min TTL
    return user

# Invalidate on write
async def update_user(user_id: str, data: dict) -> User:
    user = await db.update_user(user_id, data)
    await redis.delete(f"user:{user_id}")
    return user

# Cache stampede prevention — probabilistic early expiry
import math, random
async def get_cached(key, ttl, compute_fn):
    cached = await redis.get(key)
    if cached:
        remaining = await redis.ttl(key)
        # Probabilistic recompute before expiry
        if remaining > 0 and random.random() > math.exp(-0.001 * remaining):
            return cached
    value = await compute_fn()
    await redis.setex(key, ttl, value)
    return value
```

## Resilience Patterns

```python
# Retry with exponential backoff + jitter
import asyncio, random

async def with_retry(fn, max_retries=3, base_delay=1.0):
    for attempt in range(max_retries + 1):
        try:
            return await fn()
        except RetryableError as e:
            if attempt == max_retries:
                raise
            delay = base_delay * (2 ** attempt) + random.uniform(0, 1)
            await asyncio.sleep(delay)

# Timeout — every external call must have one
async with asyncio.timeout(5.0):
    result = await external_service.call()

# Circuit breaker (using pybreaker or tenacity)
from pybreaker import CircuitBreaker
payment_breaker = CircuitBreaker(fail_max=5, reset_timeout=30)

@payment_breaker
async def charge_card(amount, token):
    return await payment_api.charge(amount, token)
```

## Authentication Patterns

```python
# JWT — short-lived access + long-lived refresh
def create_token_pair(user_id: str):
    access = jwt.encode({
        "sub": user_id,
        "type": "access",
        "exp": datetime.utcnow() + timedelta(minutes=15),
        "jti": str(uuid4()),
    }, settings.JWT_SECRET, algorithm="HS256")

    refresh = jwt.encode({
        "sub": user_id,
        "type": "refresh",
        "exp": datetime.utcnow() + timedelta(days=30),
        "jti": str(uuid4()),  # store in DB for revocation
    }, settings.JWT_SECRET, algorithm="HS256")

    return access, refresh

# Password hashing — argon2 preferred, bcrypt acceptable
from argon2 import PasswordHasher
ph = PasswordHasher(time_cost=2, memory_cost=65536, parallelism=2)

hashed = ph.hash(password)        # store this
ph.verify(hashed, attempt)        # raises on mismatch
```

## Background Jobs

```python
# Idempotent job — safe to run twice
@celery.task(
    bind=True,
    max_retries=3,
    autoretry_for=(TransientError,),
    retry_backoff=True,
    retry_jitter=True,
)
def send_welcome_email(self, user_id: str):
    # Idempotency key prevents double-send
    if cache.get(f"welcome-sent:{user_id}"):
        return
    user = User.objects.get(id=user_id)
    email_service.send(user.email, "welcome")
    cache.set(f"welcome-sent:{user_id}", 1, ex=86400)
```

## Structured Logging

```python
import structlog
log = structlog.get_logger()

# Always include: request_id, user_id (if authed), duration
log.info("order.created",
    request_id=request.id,
    user_id=current_user.id,
    order_id=order.id,
    amount_cents=order.amount,
    duration_ms=elapsed,
)

log.error("payment.failed",
    request_id=request.id,
    order_id=order.id,
    error_code=exc.code,
    # Never log: raw card numbers, passwords, tokens, PII
)
```

## Anti-Patterns Quick Reference

| Anti-Pattern | Fix |
|-------------|-----|
| `SELECT *` | Explicit columns |
| No connection pool | PgBouncer or ORM pooling |
| External call without timeout | `asyncio.timeout()` or requests `timeout=` |
| Blocking I/O in async handler | Use async client library |
| String formatting SQL | Parameterized queries |
| Hard delete on auditable records | Soft delete (`deleted_at`) |
| Storing tokens in DB unencrypted | Store SHA-256 hash |
| POST without idempotency key | Add `Idempotency-Key` header support |
| Synchronous response > 3s | Return 202 + job ID, poll or webhook |
| Single transaction for bulk ops | Batch with savepoints |
