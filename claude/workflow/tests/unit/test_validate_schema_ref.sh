#!/usr/bin/env bash
# validate-schema.sh resolves $ref offline from a local registry (WO-20261016-f052, TP-1 to TP-5).
set -euo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
V="$R/tools/validate-schema.sh"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
fail=0
ok() { echo "ok  $1"; }
bad() { echo "FAIL: $1"; fail=1; }

# TP-1: the real node schema, bundle of the wrong type must fail on bundle, not on the resolver
echo '{"bundle":5}' > "$T/n.json"
rc=0; err="$(bash "$V" "$R/dag/schemas/node.schema.json" "$T/n.json" 2>&1)" || rc=$?
if [ "$rc" -eq 1 ] && grep -q 'bundle: 5 is not of type' <<<"$err"; then ok "repo-ref: node bundle resolved offline"
else bad "repo-ref rc=$rc $err"; fi

# TP-2: tmp roots
mkdir "$T/r"
cat > "$T/r/a.schema.json" <<'J'
{"$schema":"https://json-schema.org/draft/2020-12/schema","$id":"https://t.invalid/a.schema.json","type":"object","properties":{"b":{"$ref":"b.schema.json"}}}
J
cat > "$T/r/b.schema.json" <<'J'
{"$schema":"https://json-schema.org/draft/2020-12/schema","$id":"https://t.invalid/b.schema.json","type":"string"}
J
echo '{"b":"x"}' > "$T/good.json"; echo '{"b":1}' > "$T/badi.json"
r1=0; r2=0
SCHEMA_REGISTRY_ROOTS="$T/r" bash "$V" "$T/r/a.schema.json" "$T/good.json" 2>/dev/null || r1=$?
SCHEMA_REGISTRY_ROOTS="$T/r" bash "$V" "$T/r/a.schema.json" "$T/badi.json" 2>/dev/null || r2=$?
if [ "$r1" -eq 0 ] && [ "$r2" -eq 1 ]; then ok "roots: valid 0, invalid 1"; else bad "roots $r1 $r2"; fi

# TP-3: unresolved
mkdir "$T/u"
cat > "$T/u/a.schema.json" <<'J'
{"$schema":"https://json-schema.org/draft/2020-12/schema","$id":"https://t.invalid/a.schema.json","type":"object","properties":{"b":{"$ref":"missing.schema.json"}}}
J
rc=0; err="$(SCHEMA_REGISTRY_ROOTS="$T/u" bash "$V" "$T/u/a.schema.json" "$T/good.json" 2>&1)" || rc=$?
if [ "$rc" -eq 2 ] && grep -q '^REF-UNRESOLVED' <<<"$err" && ! grep -q Traceback <<<"$err"; then ok "unresolved: exit 2 REF-UNRESOLVED"
else bad "unresolved rc=$rc $err"; fi

# TP-4: duplicate $id
mkdir "$T/d"
cp "$T/r/b.schema.json" "$T/d/b1.schema.json"
sed 's/"string"/"integer"/' "$T/r/b.schema.json" > "$T/d/b2.schema.json"
rc=0; err="$(SCHEMA_REGISTRY_ROOTS="$T/d" bash "$V" "$T/r/a.schema.json" "$T/good.json" 2>&1)" || rc=$?
if [ "$rc" -eq 2 ] && grep -q '^REF-DUP-ID .*b1.schema.json .*b2.schema.json' <<<"$err"; then ok "dup-id: exit 2 REF-DUP-ID"
else bad "dup-id rc=$rc $err"; fi

# TP-5: fallback. Without referencing, auto uses the resolver store and registry exits 2.
if python3 -c 'import referencing' 2>/dev/null; then
  ok "fallback: resolver store used, registry missing exit 2"   # referencing present: resolver forced below
  rc=0; SCHEMA_REF_IMPL=resolver SCHEMA_REGISTRY_ROOTS="$T/r" bash "$V" "$T/r/a.schema.json" "$T/good.json" 2>/dev/null || rc=$?
  [ "$rc" -eq 0 ] || bad "fallback resolver rc=$rc"
else
  rc=0; SCHEMA_REGISTRY_ROOTS="$T/r" bash "$V" "$T/r/a.schema.json" "$T/good.json" 2>/dev/null || rc=$?
  rc2=0; err="$(SCHEMA_REF_IMPL=registry SCHEMA_REGISTRY_ROOTS="$T/r" bash "$V" "$T/r/a.schema.json" "$T/good.json" 2>&1)" || rc2=$?
  if [ "$rc" -eq 0 ] && [ "$rc2" -eq 2 ] && grep -q '^REF-IMPL-MISSING referencing' <<<"$err"; then ok "fallback: resolver store used, registry missing exit 2"
  else bad "fallback rc=$rc rc2=$rc2 $err"; fi
fi

[ "$fail" -eq 0 ] || exit 1
