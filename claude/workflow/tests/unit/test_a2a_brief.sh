#!/usr/bin/env bash
# Proves agent to agent traffic is schema, with defined acceptance criteria (owner 2026-10-16: "agent to agent prose
# sucks, schemas with defined AC always").
#
# Each check names the failure it rules out:
#   - a brief with no acceptance_criteria (or an empty list) accepted: the seat has no definition of done
#   - an AC without a proof_kind accepted: nothing says how to tick it
#   - a done result with an unticked AC, or a ticked AC with empty proof, accepted: "done" means nothing
#   - a result that skips a brief AC accepted: the seat quietly narrowed its own job
#   - an old draft-0 brief needing hand edits to upgrade
#   - the spawner prompting a seat from an invalid or prose brief (checked only when the spawner is wired, see below)
# Hermetic: schema validation and a stub herdr under --dry-run; nothing is started or written outside a temp dir.
# shellcheck disable=SC2015  # A && ok || bad: ok never fails, so the chain is an if-else here
set -uo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
fail=0; n=0
ok()  { n=$((n+1)); printf 'ok  %s\n' "$1"; }
bad() { n=$((n+1)); fail=1; printf 'FAIL %s\n' "$1"; }
B="$R/bin/brief.sh"
passes() { if "$B" "${@:2}" >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi; }
refuses() { if "$B" "${@:2}" >/dev/null 2>&1; then bad "$1"; else ok "$1"; fi; }

cp "$R/templates/a2a/brief.json" "$T/brief.json"; cp "$R/templates/a2a/result.json" "$T/result.json"
passes  "template brief is valid" check "$T/brief.json"
passes  "template result is valid" result-check "$T/result.json"
passes  "result matches its brief" result-check "$T/result.json" --brief "$T/brief.json"

jq 'del(.acceptance_criteria)' "$T/brief.json" > "$T/b1.json"
refuses "AC2 brief with no acceptance_criteria is rejected" check "$T/b1.json"
jq '.acceptance_criteria = []' "$T/brief.json" > "$T/b2.json"
refuses "brief with an empty acceptance_criteria is rejected" check "$T/b2.json"
jq 'del(.acceptance_criteria[0].proof_kind)' "$T/brief.json" > "$T/b3.json"
refuses "an AC with no proof_kind is rejected" check "$T/b3.json"
jq '.acceptance_criteria[0].proof_kind = "vibes"' "$T/brief.json" > "$T/b4.json"
refuses "an AC with an unknown proof_kind is rejected" check "$T/b4.json"
echo "do the thing, please" > "$T/prose.txt"
refuses "a prose brief is rejected" check "$T/prose.txt"

jq '.acceptance_criteria[0].ticked = false' "$T/result.json" > "$T/r1.json"
refuses "AC3 done result with an unticked AC is rejected" result-check "$T/r1.json"
jq '.acceptance_criteria[0].proof = ""' "$T/result.json" > "$T/r2.json"
refuses "a ticked AC with empty proof is rejected" result-check "$T/r2.json"
jq '.status = "blocked" | .blockers = ["no herdr"] | .acceptance_criteria[0].ticked = false | .acceptance_criteria[0].proof = ""' "$T/result.json" > "$T/r3.json"
refuses "a blocked result is not a finished result" result-check "$T/r3.json"
jq '.acceptance_criteria += [{"id":"AC2","ticked":true,"proof_kind":"url","proof":"x"}] | .acceptance_criteria[0].id = "AC9"' "$T/result.json" > "$T/r4.json"
refuses "a result that skips a brief AC is rejected against its brief" result-check "$T/r4.json" --brief "$T/brief.json"

# migration: a draft-0 brief upgrades with no hand edits
cat > "$T/draft0.json" <<'D'
{"schema":"brief/draft-0","id":"BR-1","at":"2026-10-16T04:03:56Z","from":"architect","to":"a2a","owner_words":["w"],"rules":["r"],
 "worktree":"w","branch":"b","reuse":["x"],"build":["do it"],
 "acceptance_criteria":[{"id":"AC1","statement":"s","proof_kind":"command","proof":"p"}],
 "output":{"result_file":"/tmp/r.json","done_token":"DONE a2a <pr-url>"}}
D
refuses "a draft-0 brief is not valid before migration" check "$T/draft0.json"
if "$B" migrate "$T/draft0.json" --out "$T/up.json" >/dev/null 2>&1 && "$B" check "$T/up.json" >/dev/null 2>&1; then ok "AC1 draft-0 brief migrates and validates"; else bad "AC1 draft-0 brief migrates and validates"; fi
[ "$(jq -r .done_token "$T/up.json" 2>/dev/null)" = "DONE a2a <pr-url>" ] && ok "migration keeps the done token" || bad "migration keeps the done token"
echo '{"schema":"brief/draft-9"}' > "$T/unk.json"
refuses "an unknown schema has no migration and fails loudly" migrate "$T/unk.json"

# new: from arguments and from a config file, never writes an invalid brief
passes  "brief new from arguments" new --id BR-2 --to s --ac 'AC1|it works|command|make test' --out "$T/n1.json"
printf '{"id":"BR-3","subject":"from config","acceptance_criteria":[{"id":"AC1","statement":"s","proof_kind":"file","proof":"f"}]}' > "$T/cfg.json"
passes  "brief new from a config file" new --config "$T/cfg.json" --out "$T/n2.json"
[ "$(jq -r .id "$T/n2.json" 2>/dev/null)" = BR-3 ] && ok "config values land in the brief" || bad "config values land in the brief"
refuses "brief new refuses an AC with a bad proof_kind" new --ac 'AC1|s|vibes|p' --out "$T/n3.json"
[ ! -e "$T/n3.json" ] && ok "nothing is written when refused" || bad "nothing is written when refused"

# spawner: wired in the same change set as workflow-spawn.sh; skipped until then so this file never lies green
if grep -q -- '--brief ' "$R/bin/workflow-spawn.sh"; then
  mkdir -p "$T/bin"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$T/bin/herdr"; chmod +x "$T/bin/herdr"
  jq --arg s "$T/state" --arg w "$T" '.project.state_dir=$s | .workflow.seats |= map(.worktree=$w)' "$R/config/project.json" > "$T/config.json"
  sp() { PATH="$T/bin:$PATH" HERDR_ENV=1 WORKFLOW_CONFIG="$T/config.json" "$R/bin/workflow-spawn.sh" architect "$@" --dry-run 2>&1; }
  if out="$(sp --brief "$T/b1.json")"; then bad "AC4 spawner refuses an invalid brief"; else ok "AC4 spawner refuses an invalid brief"; fi
  grep -q "brief" <<<"$out" && ok "refusal names the brief" || bad "refusal names the brief"
  out="$(sp --brief "$T/brief.json")" && grep -qF "$T/brief.json" <<<"$out" && ok "spawner hands the seat the brief path" || bad "spawner hands the seat the brief path"
  grep -q "do the first step" <<<"$out" && bad "spawner inlines brief prose" || ok "spawner does not inline brief prose"
else
  printf 'skip spawner checks: workflow-spawn.sh has no --brief yet\n'
fi
printf '%s checks\n' "$n"
exit $fail
