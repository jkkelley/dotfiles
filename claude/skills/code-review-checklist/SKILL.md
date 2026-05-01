---
name: code-review-checklist
description: Comprehensive code review checklist covering security, performance, correctness, and maintainability across all languages. Preloaded into the polyglot-code-reviewer agent.
---

# Code Review Checklist

## Severity Levels

| Level | Label | Action |
|-------|-------|--------|
| 🚨 Critical | Data loss, security vuln, crash | Block merge, escalate |
| ⚠️ Major | Correctness, reliability, perf | Must fix before merge |
| 💡 Minor | Clarity, better patterns | Fix if time allows |
| 🔍 Nit | Style, naming | Optional |

## Security Review (Check Every PR)

```
[ ] SQL: no string concatenation — parameterized queries only
[ ] Shell: no user input in exec/system/subprocess without sanitization
[ ] Auth: auth/authz checked before every sensitive operation
[ ] Secrets: no hardcoded API keys, passwords, tokens anywhere
[ ] Logging: no PII, secrets, or sensitive data in log statements
[ ] Input validation: all external input validated at boundary
[ ] Deserialization: untrusted data not passed to pickle/yaml.load/eval
[ ] Path traversal: user input doesn't influence file paths without sanitization
[ ] CSRF/XSS: relevant for web endpoints
[ ] Dependencies: new deps checked for known CVEs, typosquatting
```

## Correctness Checklist

```
[ ] Edge cases: empty input, null/nil, zero, negative, max int, empty list
[ ] Off-by-one: loop bounds, slice indices, pagination offsets
[ ] Integer overflow: arithmetic on user-controlled values
[ ] Concurrent access: shared state accessed from multiple goroutines/threads
[ ] Error handling: all errors checked, not just ignored or logged
[ ] Resource cleanup: files, connections, locks closed in all code paths
[ ] Idempotency: operations safe to retry/run twice
[ ] Race conditions (TOCTOU): check-then-act patterns
```

## Performance Checklist

```
[ ] N+1 queries: loop with individual DB calls instead of JOIN/eager load
[ ] Unnecessary allocations in hot paths
[ ] O(n²) or worse where O(n log n) available
[ ] Blocking I/O in async/non-blocking context
[ ] Missing index on filtered/joined columns (SQL)
[ ] Unbounded queries: no LIMIT on user-controlled result sets
[ ] Cache stampede: multiple threads recomputing same expensive value
```

## Language-Specific Footguns

### Python
```python
# Mutable default argument — WRONG
def add_item(item, lst=[]):   # lst shared across all calls!
    lst.append(item)

# Correct
def add_item(item, lst=None):
    if lst is None: lst = []
    lst.append(item)

# Sync call in async context — WRONG
async def handler():
    result = requests.get(url)  # blocks event loop!

# Bare except — WRONG (catches SystemExit, KeyboardInterrupt)
try: ...
except: pass
```

### Go
```go
// Ignored error — WRONG
result, _ := doSomething()

// Goroutine leak — no way to stop
go func() { for { work() } }()  // needs context cancellation

// defer in loop — runs at function end, not loop iteration
for _, f := range files {
    defer f.Close()  // all deferred until function returns
}
```

### JavaScript/TypeScript
```js
// any type — defeats TypeScript
const data: any = response.json()  // use unknown + type guard

// == instead of ===
if (x == null)  // catches null AND undefined — usually unintentional

// Unhandled promise rejection
fetchData()  // missing .catch() or await in try/catch

// useEffect cleanup missing
useEffect(() => {
    const id = setInterval(fn, 1000)
    // missing: return () => clearInterval(id)
}, [])
```

### SQL
```sql
-- SQL injection
"SELECT * FROM users WHERE name = '" + name + "'"  -- NEVER

-- SELECT * in production code
SELECT * FROM orders  -- always explicit columns

-- Missing LIMIT
SELECT * FROM logs WHERE user_id = ?  -- could return millions of rows

-- N+1
for order in orders:
    SELECT * FROM items WHERE order_id = order.id  -- join instead
```

### Java/Kotlin
```java
// Unclosed resource
InputStream is = new FileInputStream(file);  // missing try-with-resources
// Correct: try (InputStream is = new FileInputStream(file)) { ... }

// Broken equals/hashCode contract
class Point {
    public boolean equals(Object o) { ... }
    // forgot to override hashCode — breaks HashMap
}
```

## Maintainability Checklist

```
[ ] Function length: >50 lines usually needs decomposition
[ ] Cyclomatic complexity: deeply nested if/else → extract functions
[ ] Magic numbers: use named constants
[ ] Error messages: actionable (what failed + what to do)
[ ] No dead code: commented-out blocks, unreachable branches
[ ] Tests exist and are meaningful (not just coverage theater)
[ ] New public API has documentation
```

## Review Output Format

```
## [File] Assessment

### 🚨 Critical
- Line 42: SQL injection — `"SELECT * FROM users WHERE id=" + userId`
  Fix: use parameterized query `db.query("SELECT * FROM users WHERE id=?", userId)`

### ⚠️ Major
- Line 87: goroutine leak — no context cancellation
  The goroutine started here has no way to stop if the request is cancelled.

### 💡 Minor
- Line 23: mutable default argument in Python
  `def process(items=[])` — each call shares the same list object.

### 🔍 Nit
- Line 15: `getData` → `fetchUserProfile` (more descriptive)
```
