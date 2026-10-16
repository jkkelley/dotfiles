#!/usr/bin/env bash
# rolodex: header drafted by scripts/rolodex.py headers - correct any line that is wrong
# name: 460-ac-expect-multiline.sh
# purpose: Assert check matches an --ac-expect regex across lines when the per-line match misses, and keeps the per-line verdict when grep -P is unsupported (WO-20261016-49e1).
# inputs: env SKILL (skill root, default /skill); sourced assert.sh helpers
# outputs: exit code 0 when every assertion passes, assertion lines on stdout
# writes-to: scratch project dirs under $WORK (mktemp), removed with the test sandbox
# cleanup: the sandbox container is discarded; nothing outside $WORK is touched
# The reason this case exists.
#
# WO-20261016-64f2 index 2 expect spans five lines and ends in ^1000$. check
# handed the output to grep one line at a time, so no such regex could match and
# a correct ticket read AC-FAIL (DESIGN-GAP a1ca). The widened match must pass
# the multi-line shape, still fail a non-matching one, and fall back to the
# per-line verdict when grep -P exits 2 (BusyBox).
source "${SKILL:-/skill}/testing/assert.sh"

wos() { bash "$SKILL/scripts/work-order.sh" "$@"; }
export PATH="$(gh_stub "$WORK/stub-460" MERGED cafebabe1234 ""):$PATH"
cmd="printf 'gh version 2.101.0\n0.5.0\njsonschema-ok\ntools-ok\n1000\n'"

# verdict <expect> [PATH prefix]: prints the check line for a fresh one-criterion ticket.
verdict() {
  local expect="$1" pre="${2-}" d id
  d=$(git_project)
  wos new --project "$d" --title "Multiline" --type feature --problem P --top-level --out X \
    --owner-words W --context C --ac "spans lines" --ac-check "$cmd" --ac-exit 0 --ac-expect "$expect" >/dev/null
  id=$(wos list --project "$d" --json | jq -r '.[0].id')
  git -C "$d" add -A && git -C "$d" commit -qm add
  wos approve --project "$d" --id "$id" --no-lavish --reason "no lavish in CI" >/dev/null
  git -C "$d" add -A && git -C "$d" commit -qm approve
  wos start --project "$d" --id "$id" >/dev/null
  PATH="$pre$PATH" wos check --project "$d" --id "$id" 2>&1
}

out=$(verdict 'gh version 2\.101\.0[\s\S]*tools-ok[\s\S]*^1000$')
case $out in *"AC-PASS 1"*) _pass "a multi-line expect gives AC-PASS" ;; *) _fail "multi-line expect not AC-PASS" "$out" ;; esac
out=$(verdict '^0\.5\.0$')
case $out in *"AC-PASS 1"*) _pass "a single-line expect still gives AC-PASS" ;; *) _fail "single-line expect not AC-PASS" "$out" ;; esac
out=$(verdict 'gh version 9[\s\S]*^1000$')
case $out in *"AC-FAIL 1"*) _pass "a non-matching multi-line expect still gives AC-FAIL" ;; *) _fail "non-matching expect not AC-FAIL" "$out" ;; esac

# grep stub: exits 2 on -P (unsupported), otherwise the real grep.
real=$(command -v grep)
mkdir -p "$WORK/grep-460"
cat >"$WORK/grep-460/grep" <<STUB
#!/usr/bin/env bash
for a in "\$@"; do case \$a in -*P*) exit 2 ;; esac; done
exec $real "\$@"
STUB
chmod +x "$WORK/grep-460/grep"
out=$(verdict 'gh version 2\.101\.0[\s\S]*tools-ok[\s\S]*^1000$' "$WORK/grep-460:")
case $out in *"AC-FAIL 1"*) _pass "grep -P unsupported keeps the multi-line expect AC-FAIL" ;; *) _fail "fallback not AC-FAIL" "$out" ;; esac
out=$(verdict '^0\.5\.0$' "$WORK/grep-460:")
case $out in *"AC-PASS 1"*) _pass "grep -P unsupported keeps the single-line expect AC-PASS" ;; *) _fail "fallback single-line not AC-PASS" "$out" ;; esac
