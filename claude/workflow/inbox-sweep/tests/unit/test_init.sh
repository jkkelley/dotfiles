#!/usr/bin/env bash
# AC-H1, AC-H2, AC-H3 for node B3: sweep-init.sh, the run dir, run.json and the rendered briefs.
# Rules out: a run that starts without the owner's words (F3, the seats improvised), a half-made run dir left behind
# by a refused init, a run id that is not UTC-shaped, a Proton account that gets no seat or two accounts that share a
# brief, an owner-words block that a `$` in the owner's text corrupts at render time, and a disabled seat that still
# gets a brief.
# shellcheck disable=SC2016,SC2015 # literal ${..} text is the point; `a && b && echo yes` is a yes/no probe, not an if-else
set -uo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=_t.sh
. "$R/tests/unit/_t.sh"
INIT="$R/bin/sweep-init.sh"
F="$R/tests/fixtures"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
export SWEEP_WIN_HOME="$T/winhome"
export SWEEP_CONFIG="$F/config/valid.json"
export SWEEP_OWNER_WORDS="$F/owner-words.md"
fresh() { export SWEEP_RUNS_ROOT="$T/$1/runs" SWEEP_LATEST="$T/$1/latest"; }
briefs_of() { find "$1" -name '*.md' -printf '%f\n' | sed 's/\.md$//' | sort | paste -sd' '; }

# AC-H1 missing and empty owner words
fresh missing
out="$(SWEEP_OWNER_WORDS="$T/nope.md" bash "$INIT" --seats all 2>"$T/err")"; rc=$?
check 3 "$rc" "missing owner words exits 3"
check yes "$(grep -q '^PF-NO-OWNER-WORDS' "$T/err" && echo yes)" "missing owner words names PF-NO-OWNER-WORDS"
check "" "$out" "a refused init prints no run id"
check 0 "$(find "$T/missing" 2>/dev/null | wc -l)" "a refused init creates no run dir, no root and no latest link"
printf '  \n\n' >"$T/blank.md"
fresh blank
SWEEP_OWNER_WORDS="$T/blank.md" bash "$INIT" --seats all >/dev/null 2>"$T/err"; rc=$?
check 3 "$rc" "whitespace-only owner words exits 3"
check 0 "$(find "$T/blank" 2>/dev/null | wc -l)" "whitespace-only owner words creates nothing"

# invalid config and usage
fresh bad
SWEEP_CONFIG="$F/config/invalid-no-accounts.json" bash "$INIT" --seats all >/dev/null 2>"$T/err"; rc=$?
check 1 "$rc" "an invalid config exits 1"
check 0 "$(find "$T/bad" 2>/dev/null | wc -l)" "an invalid config creates no run dir"
bash "$INIT" --seats nonsense >/dev/null 2>&1; check 2 "$?" "an unknown --seats value exits 2"
bash "$INIT" >/dev/null 2>&1; check 2 "$?" "no arguments exits 2"

# AC-H2 and AC-H3: a good run with the 2-account config
fresh good
id="$(bash "$INIT" --seats all 2>"$T/err")"; rc=$?
check 0 "$rc" "a good init exits 0"
check yes "$([[ $id =~ ^[0-9]{8}T[0-9]{6}Z$ ]] && echo yes)" "run id matches ^[0-9]{8}T[0-9]{6}Z\$"
run="$T/good/runs/$id"
check yes "$([ -d "$run/results" ] && [ -d "$run/logs" ] && [ -d "$run/briefs" ] && echo yes)" "results, logs and briefs dirs exist"
check "$run" "$(readlink "$T/good/latest")" "latest points at the new run"
check "$id" "$(jq -r .run_id "$run/run.json")" "run.json run_id equals the dir name"
check RUN-RUNNING "$(jq -r .status "$run/run.json")" "run.json status is RUN-RUNNING"
check "gmail linkedin proton-first proton-second" "$(briefs_of "$run/briefs")" "one brief per enabled seat, two for the 2-account Proton config"
check 4 "$(jq '.seats | length' "$run/run.json")" "run.json lists 4 seats"
check "gmail linkedin proton-first proton-second" "$(jq -r '[.seats[].seat] | sort | join(" ")' "$run/run.json")" "run.json seat names match the briefs"
check yes "$(grep -q 'first@example.com' "$run/briefs/proton-first.md" && ! grep -q 'second@example.com' "$run/briefs/proton-first.md" && echo yes)" "the first Proton brief names its own account only"
check yes "$(grep -q 'second@example.com' "$run/briefs/proton-second.md" && ! grep -q 'first@example.com' "$run/briefs/proton-second.md" && echo yes)" "the second Proton brief names its own account only"
for b in "$run"/briefs/*.md; do
  n="$(basename "$b")"
  check 1 "$(grep -c '^<owner-words>$' "$b")" "$n holds one owner-words block"
  check yes "$(grep -qF 'Sweep my inboxes and tell me what needs me.' "$b" && echo yes)" "$n carries the owner's text"
  check yes "$(grep -qF 'Costs $5 and ${HOME} are examples' "$b" && echo yes)" "$n keeps a literal \$ and \${HOME} from the owner's text unexpanded"
  check 0 "$(grep -cE '\$\{(RUN_ID|SEAT|ACCOUNT|DEADLINE_AT|RESULT_PATH|SCHEMA_PATH|MARK_READ)\}' "$b")" "$n has no unreplaced render variable"
  check yes "$(grep -q "^Result path: .*results/${n%.md}.json$" "$b" && echo yes)" "$n names its own result file"
done
check "Dated (UTC): $(date -u -r "$F/owner-words.md" +%Y-%m-%dT%H:%M:%SZ)" "$(sed -n '/^<owner-words>$/,/^<\/owner-words>$/p' "$run/briefs/gmail.md" | sed -n 2p)" "the owner words open with the file's UTC date"
check "$(sha256sum "$F/owner-words.md" | cut -d' ' -f1)" "$(jq -r .owner_words_sha256 "$run/run.json")" "run.json holds the sha256 of the owner words"
check yes "$(jq -r '[.seats[].deadline_at | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z$")] | all | if . then "yes" else "no" end' "$run/run.json")" "every seat deadline is a UTC timestamp"
check true "$(jq -r '(.seats[0].deadline_at | fromdate) - (.started_at | fromdate) | . >= 2390 and . <= 2410' "$run/run.json")" "the seat deadline is 40 minutes after the start"
check "true" "$(grep -q 'Mark read: true' "$run/briefs/gmail.md" && echo true)" "mark_read true from the config reaches the brief"
check 3 "$(wc -l <"$run/checklist.jsonl")" "three checklist rows are recorded"
check yes "$(grep -q 'equals seats 4' "$run/logs/init.log" && echo yes)" "logs/init.log records the owner-words count against the seat count"

# --seats filters, and a disabled seat gets no brief
fresh proton
id="$(bash "$INIT" --seats proton 2>/dev/null)"
check "proton-first proton-second" "$(briefs_of "$T/proton/runs/$id/briefs")" "--seats proton makes only the Proton briefs"
jq '.gmail.enabled=false | .linkedin.enabled=false | .mark_read=false' "$F/config/valid.json" >"$T/cfg-off.json"
fresh off
id="$(SWEEP_CONFIG="$T/cfg-off.json" bash "$INIT" --seats all 2>/dev/null)"
check "proton-first proton-second" "$(briefs_of "$T/off/runs/$id/briefs")" "disabled Gmail and LinkedIn get no brief"
check yes "$(grep -q 'Mark read: false' "$T/off/runs/$id/briefs/proton-first.md" && echo yes)" "mark_read false reaches the brief"
fresh none
SWEEP_CONFIG="$T/cfg-off.json" bash "$INIT" --seats gmail >/dev/null 2>&1; rc=$?
check 1 "$rc" "a --seats value with no enabled seat exits 1"
check 0 "$(find "$T/none" 2>/dev/null | wc -l)" "and creates nothing"

# Mutation: a template without the owner-words block must stop the run, or AC-H1 would hold only for good templates.
cp -r "$R/templates" "$T/tpl"
sed -i '/^<owner-words>$/,/^<\/owner-words>$/d' "$T/tpl/brief-gmail.md"
mkdir -p "$T/sweepcopy" && cp -r "$R/bin" "$R/schemas" "$T/sweepcopy/" && cp -r "$T/tpl" "$T/sweepcopy/templates"
mkdir -p "$T/tools" && cp "$R/../tools/validate-schema.sh" "$T/tools/"
fresh mut
bash "$T/sweepcopy/bin/sweep-init.sh" --seats gmail >/dev/null 2>"$T/err"; rc=$?
check 1 "$rc" "a template that lost its owner-words block stops the run"
finish
