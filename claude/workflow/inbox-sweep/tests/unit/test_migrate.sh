#!/usr/bin/env bash
# B21: copy-forward migration runner, rollback, and the nodes-check rule that a schema bump ships a migration.
#   AC-H1 a v1 fixture upgrades to v2 and validates
#   AC-H2 the v1 file is still present after
#   AC-H3 rollback restores the pinned versions and the run finishes
#   AC-H4 a schema bump with no migration and test fails nodes-check
#   AC-H5 a migration that would change an approved text refuses
# Every case works in a temp dir; the tree is mounted read-only and never written.
set -uo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=_t.sh
. "$(dirname "${BASH_SOURCE[0]}")/_t.sh"
# shellcheck source=../../bin/node-lib.sh
. "$R/bin/node-lib.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
FIX="$R/tests/fixtures/migrations/fixture/v1.json"
export MIGRATE_PINS="$T/pins.json"
M() { bash "$R/bin/migrate.sh" "$@"; }
fresh() { rm -rf "$T/d" "$MIGRATE_PINS"; mkdir -p "$T/d"; cp "$FIX" "$T/d/fixture.json"; }
valid() { python3 -I - "$1" "$R/schemas/records/fixture.v$2.schema.json" <<'PY'
import json, sys
from jsonschema import Draft202012Validator
v = Draft202012Validator(json.load(open(sys.argv[2])))
sys.exit(1 if [e for l in open(sys.argv[1]) if l.strip() for e in v.iter_errors(json.loads(l))] else 0)
PY
}

# AC-H1 and AC-H2
fresh; before="$(sha256sum "$T/d/fixture.json" | cut -d' ' -f1)"
out="$(M migrate "$T/d")"; check 0 "$?" "AC-H1 make migrate exits 0 over a v1 record"
check yes "$(grep -q 'MIG-OK' <<<"$out" && echo yes)" "AC-H1 the runner reports MIG-OK"
check yes "$([ -f "$T/d/fixture.v2.json" ] && echo yes)" "AC-H1 the v2 copy is written beside the original"
valid "$T/d/fixture.v2.json" 2; check 0 "$?" "AC-H1 the v2 copy validates against fixture.v2.schema.json"
check 2 "$(jq -r .schema_version "$T/d/fixture.v2.json")" "AC-H1 the copy says schema_version 2"
check yes "$([ -f "$T/d/fixture.json" ] && echo yes)" "AC-H2 the v1 file is still present"
check "$before" "$(sha256sum "$T/d/fixture.json" | cut -d' ' -f1)" "AC-H2 the v1 file is byte-identical"
out="$(M migrate "$T/d")"; check 0 "$?" "a second migrate is a no-op, not an error"
check yes "$(grep -q 'MIG-CURRENT' <<<"$out" && echo yes)" "a second migrate reports MIG-CURRENT"
check 1 "$(find "$T/d" -name 'fixture.v*' | wc -l)" "a second migrate writes no further file"

# the same runner over a .jsonl, one record per line, two files at once
fresh; { cat "$FIX"; jq -c '.id="card-2"' "$FIX"; } >"$T/d/fixture2.jsonl"; cp "$FIX" "$T/d/fixture3.json"
mkdir -p "$T/rs"; cp "$R"/schemas/records/* "$T/rs/"; for v in 1 2; do cp "$T/rs/fixture.v$v.schema.json" "$T/rs/fixture2.v$v.schema.json"; cp "$T/rs/fixture.v$v.schema.json" "$T/rs/fixture3.v$v.schema.json"; done
mkdir -p "$T/ms"; for n in fixture fixture2 fixture3; do mkdir -p "$T/ms/$n"; cp "$R/migrations/fixture/v1-to-v2.sh" "$T/ms/$n/"; done
REC_SCHEMA_DIR="$T/rs" MIG_DIR="$T/ms" M migrate "$T/d" >/dev/null; check 0 "$?" "a .jsonl and several record files migrate in one run"
check 2 "$(wc -l <"$T/d/fixture2.v2.jsonl" | tr -d ' ')" "every line of a .jsonl is migrated"
check yes "$([ -f "$T/d/fixture3.v2.json" ] && echo yes)" "each record file gets its own copy"

# AC-H3: rollback repoints the pins, sets the v2 copy aside, and a run reading by the pins still finishes
fresh; M migrate "$T/d" >/dev/null
check "$T/d/fixture.v2.json" "$(M resolve "$T/d" fixture)" "before rollback new runs read the v2 copy"
out="$(M rollback R1 1.0.0 fixture 1 "$T/d")"; check 0 "$?" "AC-H3 rollback exits 0"
check "1.0.0" "$(jq -r .nodes.R1 "$MIGRATE_PINS")" "AC-H3 the node pin is restored"
check 1 "$(jq -r .records.fixture "$MIGRATE_PINS")" "AC-H3 the record pin is restored"
check "$T/d/fixture.json" "$(M resolve "$T/d" fixture)" "AC-H3 new runs read the v1 record again"
check no "$([ -f "$T/d/fixture.v2.json" ] && echo yes || echo no)" "AC-H3 the v2 copy is set aside, not left live"
check yes "$([ -f "$T/d/fixture.v2.json.rolled-back" ] && echo yes)" "AC-H3 the v2 copy is kept for prune, not deleted"
valid "$(M resolve "$T/d" fixture)" 1; check 0 "$?" "AC-H3 the run finishes: the resolved record validates at the pinned version"
M migrate "$T/d" >/dev/null; check 0 "$?" "AC-H3 migrate after rollback does not undo it"
check no "$([ -f "$T/d/fixture.v2.json" ] && echo yes || echo no)" "AC-H3 a pinned-back record is not migrated forward again"
M rollback R1 1.0 fixture 1 "$T/d" >/dev/null 2>&1; check 2 "$?" "rollback refuses a TO that is not semver"
M rollback R1 1.0.0 fixture 9 "$T/d" >/dev/null 2>&1; check 2 "$?" "rollback refuses a schema version with no schema"

# AC-H4
rm -rf "$T/rec" "$T/mig" "$T/fx" "$T/n" "$T/s"; mkdir -p "$T/rec" "$T/mig/fixture" "$T/fx/fixture" "$T/n" "$T/s"
cp "$R"/nodes/*.node.json "$T/n/"; cp "$R"/schemas/records/* "$T/rec/"; cp "$R/migrations/fixture/v1-to-v2.sh" "$T/mig/fixture/"; cp "$FIX" "$T/fx/fixture/"
cp "$R/../../../docs/design/inbox-sweep.md" "$T/design.md"
NC() { NODE_DIR="$T/n" NODE_DESIGN="$T/design.md" NODE_SCRIPTS="$T/s" REC_DIR="$T/rec" MIG_DIR="$T/mig" MIG_FIX="$T/fx" node_check 2>&1; }
NC >/dev/null; check 0 "$?" "AC-H4 a bump that ships its migration and fixture passes nodes-check"
cp "$T/rec/fixture.v2.schema.json" "$T/rec/fixture.v3.schema.json"
out="$(NC)"; check 1 "$?" "AC-H4 a v3 schema with no migration fails nodes-check"
check yes "$(grep -q 'fixture.v3.schema.json raises fixture to v3 with no migration' <<<"$out" && echo yes)" "AC-H4 the failure names the schema and the missing script"
cp "$T/mig/fixture/v1-to-v2.sh" "$T/mig/fixture/v2-to-v3.sh"
out="$(NC)"; check 1 "$?" "AC-H4 a migration with no test fixture still fails"
check yes "$(grep -q 'no test fixture fixture/v2.json' <<<"$out" && echo yes)" "AC-H4 the failure names the missing fixture"
cp "$FIX" "$T/fx/fixture/v2.json"; NC >/dev/null; check 0 "$?" "AC-H4 migration plus fixture clears the failure"

# AC-H5: a migration that rewrites the approved text is refused, and nothing is written
fresh; rm -rf "$T/ms2"; mkdir -p "$T/ms2/fixture"
cat >"$T/ms2/fixture/v1-to-v2.sh" <<'SH'
#!/usr/bin/env bash
jq -c '.schema_version = 2 | .envelope = {migrated_from: 1} | .text = (.text + " Cheers!")'
SH
chmod +x "$T/ms2/fixture/v1-to-v2.sh"
out="$(MIG_DIR="$T/ms2" M migrate "$T/d")"; check 1 "$?" "AC-H5 a migration that edits the text makes migrate fail"
check yes "$(grep -q 'MIG-REFUSED-TEXT' <<<"$out" && echo yes)" "AC-H5 the code is MIG-REFUSED-TEXT"
check 1 "$(find "$T/d" -name 'fixture*' | wc -l)" "AC-H5 no migrated file is written"
check "$(sha256sum <"$FIX")" "$(sha256sum <"$T/d/fixture.json")" "AC-H5 the original is untouched"
# the hash edited instead of the text is the same refusal
cat >"$T/ms2/fixture/v1-to-v2.sh" <<'SH'
#!/usr/bin/env bash
jq -c '.schema_version = 2 | .envelope = {migrated_from: 1} | .text_sha256 = ("0" * 64)'
SH
out="$(MIG_DIR="$T/ms2" M migrate "$T/d")"; check yes "$(grep -q 'MIG-REFUSED-TEXT' <<<"$out" && echo yes)" "AC-H5 editing text_sha256 is refused too"
# one refusal does not stop the other record files
cp "$FIX" "$T/d/good.json"; mkdir -p "$T/ms3/good"; cp "$R/migrations/fixture/v1-to-v2.sh" "$T/ms3/good/"
cp "$T/ms2/fixture/v1-to-v2.sh" "$T/ms3/fixture/" 2>/dev/null || { mkdir -p "$T/ms3/fixture"; cp "$T/ms2/fixture/v1-to-v2.sh" "$T/ms3/fixture/"; }
for v in 1 2; do cp "$R/schemas/records/fixture.v$v.schema.json" "$T/rs/good.v$v.schema.json"; done
REC_SCHEMA_DIR="$T/rs" MIG_DIR="$T/ms3" M migrate "$T/d" >/dev/null; check 1 "$?" "a refusal makes the run exit non-zero"
check yes "$([ -f "$T/d/good.v2.json" ] && echo yes)" "a refusal on one file does not stop the others"
finish
