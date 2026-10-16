#!/usr/bin/env bash
# name: autofix.test.sh
# purpose: dev gate for the pr-flow-consume.sh autofix verb - a mechanical red is fixed and pushed once per head, a content red is left to the worker
# inputs: bin/pr-flow-consume.sh and the scripts beside it; a fixture clone with a bare origin, a fake gh, a fixture md-contents.sh and a stub publisher in a mktemp directory
# outputs: ok/FAIL lines and pass= fail=; exit 1 on any failure
# writes-to: a mktemp directory
# cleanup: the mktemp directory is removed on exit
# shellcheck disable=SC2015
set -uo pipefail
PF=$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT; mkdir -p "$W/bin" "$W/state" "$W/dot/scripts"
pass=0; fail=0
ok() { pass=$((pass + 1)); echo "ok   $1"; }
no() { fail=$((fail + 1)); echo "FAIL $1"; }
eq() { [ "$2" = "$3" ] && ok "$1" || no "$1: got '$2' want '$3'"; }
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com
# shellcheck disable=SC2016
printf '#!/usr/bin/env bash\necho "$1 $2" >> "%s/pub.log"\n' "$W" > "$W/bin/pub"; chmod +x "$W/bin/pub"; : > "$W/pub.log"
# fixture md-contents.sh: check fails while the stale marker exists, write clears it and edits a tracked .md
cat > "$W/dot/scripts/md-contents.sh" <<MD
#!/usr/bin/env bash
case \$1 in
  check) [ ! -e stale.marker ] ;;
  write) rm -f stale.marker; echo fixed >> doc.md ;;
esac
MD
cfg() { # cfg MODE
  cat > "$W/cfg.json" <<CFG
{"defaults": {"line": "test", "records": "bus", "ticket_re": "(WO-[0-9]{8}-[0-9a-f]{4})", "required_check": "ci-ok", "regen": {"paths": ""},
  "cleanup": {"slots": false}, "backstop_s": 0, "stale_red": {"mode": "off"}, "budgets": {"sweep": {"budget_s": 60, "timeout_s": 60}},
  "autofix": {"mode": "$1", "on_checks": "^(headers|markdown contents lists)\$",
   "fixes": [{"name": "tracked-ignored", "detect": "test -z \\"\$(git ls-files -ci --exclude-standard)\\"", "fix": "git ls-files -ci -z --exclude-standard | xargs -0r git rm --cached -q"},
             {"name": "md-contents", "detect": "BASE=origin/\$PR_BASE bash \\"\$DOTFILES/scripts/md-contents.sh\\" check", "fix": "BASE=origin/\$PR_BASE bash \\"\$DOTFILES/scripts/md-contents.sh\\" write"}]}},
 "repos": {"o/r": {"clone": "$W/clone"}}}
CFG
}
# fixture: bare origin, a clone, branch pr with an ignored tracked path and a stale marker
git init -q --bare -b main "$W/origin.git"; git clone -q "$W/origin.git" "$W/clone" 2>/dev/null
( cd "$W/clone" && git checkout -q -b main && echo ignored.log > .gitignore && echo doc > doc.md && git add -A && git commit -q -m base && git push -q origin main \
  && git checkout -q -b pr && echo x > ignored.log && echo y > stale.marker && git add -f ignored.log stale.marker && git commit -q -m pr && git push -q origin pr && git checkout -q main )
newhead() { git -C "$W/origin.git" rev-parse pr; }
HEAD1=$(newhead)
cat > "$W/bin/gh" <<'FAKE'
#!/usr/bin/env bash
JQ=""; a=(); while [ $# -gt 0 ]; do if [ "$1" = --jq ]; then JQ=$2; shift 2; else a+=("$1"); shift; fi; done; set -- "${a[@]}"
out() { if [ -n "$JQ" ]; then jq -r "$JQ" <<<"$1"; else printf '%s\n' "$1"; fi; }
case "$*" in
  "pr list -R o/r --state open"*) out "[{\"number\": 1, \"headRefOid\": \"$($REALGIT -C "$W/origin.git" rev-parse pr)\", \"title\": \"feat: x\", \"body\": \"WO-20261016-aaaa - x\", \"baseRefName\": \"main\", \"headRefName\": \"pr\", \"isCrossRepository\": $(cat "$W/fork")}]" ;;
  "pr list -R o/r --state merged"*) out '[]' ;;
  "api repos/o/r/commits/"*"/check-runs"*) out "$(cat "$W/checks.json")" ;;
  *) echo "fake gh: unexpected $*" >&2; exit 9 ;;
esac
FAKE
chmod +x "$W/bin/gh"
mkdir -p "$W/pf/bin"; cp "$PF"/bin/*.sh "$W/pf/bin/"; cp -r "$PF/schemas" "$W/pf/"
printf '#!/usr/bin/env bash\nexit 0\n' > "$W/pf/bin/gate.sh"; chmod +x "$W/pf/bin/gate.sh"
REALGIT=$(command -v git); export REALGIT
export W GH="$W/bin/gh" PR_FLOW_PUB="$W/bin/pub" PR_FLOW_STATE="$W/state" PR_FLOW_CONFIG="$W/cfg.json" RECORDS_BACKOFF=0 GATE_BACKOFF=0 PR_FLOW_UNTIMED=1 DOTFILES="$W/dot"
echo false > "$W/fork"
red() { echo "{\"check_runs\": [{\"name\": \"$1\", \"status\": \"completed\", \"conclusion\": \"failure\", \"started_at\": \"2026-10-16T07:00:00Z\", \"completed_at\": \"2026-10-16T07:00:00Z\"}]}" > "$W/checks.json"; }
tick() { REPO=o/r "$W/pf/bin/pr-flow-consume.sh" "${1:-sweep}"; }
recs() { grep -c '^line.test.event.ci.autofix ' "$W/pub.log"; }
reset() { : > "$W/pub.log"; rm -rf "$W/state"; mkdir "$W/state"; }
nowt() { eq "$1 no temp worktree left" "$(git -C "$W/clone" worktree list | wc -l | tr -d ' ')" 1; }

# TP-1: a mechanical red gets one commit, pushed, one AUTOFIX record
cfg on; red "markdown contents lists"; tick > "$W/out1" 2>&1
git -C "$W/origin.git" log pr --format=%s -1 | grep -q '^chore: pr-flow autofix tracked-ignored+md-contents (AUTOFIX)$' && ok "TP-1 one autofix commit on the head branch" || no "TP-1 commit: $(git -C "$W/origin.git" log pr --format=%s -2 | tr '\n' '|')"
git -C "$W/origin.git" ls-tree -r --name-only pr | grep -qx ignored.log && no "TP-1 ignored.log still tracked" || ok "TP-1 ignored path untracked"
git -C "$W/origin.git" ls-tree -r --name-only pr | grep -qx stale.marker && no "TP-1 stale list not rewritten" || ok "TP-1 contents list rewritten"
eq "TP-1 one AUTOFIX record" "$(recs)" 1
grep '^line.test.event.ci.autofix ' "$W/pub.log" | cut -d' ' -f2- | jq -e '.code == "AUTOFIX" and .pr == 1 and .repo == "o/r"' >/dev/null && ok "TP-1 code AUTOFIX, pr 1" || no "TP-1 record: $(cat "$W/pub.log")"
"$W/pf/bin/records.sh" seen --key "AUTOFIX/o/r/1/$HEAD1" && ok "TP-1 key AUTOFIX/o/r/1/<head> marked posted" || no "TP-1 key not marked"
nowt TP-1

# TP-2: the pushed head is new and green-or-red alike; the same head again pushes and posts nothing
HEAD2=$(newhead); : > "$W/pub.log"
git -C "$W/origin.git" update-ref refs/heads/pr "$HEAD1"; tick > "$W/out2" 2>&1
eq "TP-2 same head: no second record" "$(recs)" 0
eq "TP-2 same head: head untouched" "$(newhead)" "$HEAD1"
git -C "$W/origin.git" update-ref refs/heads/pr "$HEAD2"

# TP-3: nothing mechanical to fix is the worker's; marker stops a retry, 422 still posted
reset; git -C "$W/clone" fetch -q origin pr; ( cd "$W/clone" && git checkout -q main )
git -C "$W/clone" worktree add -q --detach "$W/t3" origin/pr; ( cd "$W/t3" && echo z >> doc.md && git commit -qam content && git push -q origin HEAD:pr ); git -C "$W/clone" worktree remove --force "$W/t3"
red headers; tick > "$W/out3" 2>&1
grep -q '^o/r PR 1 autofix-none' "$W/out3" && ok "TP-3 prints autofix-none" || no "TP-3 stdout: $(cat "$W/out3")"
eq "TP-3 no AUTOFIX record" "$(recs)" 0
eq "TP-3 ci.failed 422 still posted" "$(grep -c '^line.test.event.ci.failed ' "$W/pub.log")" 1
H3=$(newhead); tick > "$W/out3b" 2>&1; grep -q autofix-none "$W/out3b" && no "TP-3 marker ignored" || ok "TP-3 marker: no second attempt"
eq "TP-3 head untouched" "$(newhead)" "$H3"
nowt TP-3

# TP-4: fallbacks: refused push, fork PR, mode off
reset; ( cd "$W/clone" && git worktree add -q --detach "$W/t4" origin/pr && cd "$W/t4" && echo y > stale.marker && git add stale.marker && git commit -qm stale && git push -q origin HEAD:pr ) ; git -C "$W/clone" worktree remove --force "$W/t4"
cp "$W/origin.git/hooks/pre-receive.sample" /dev/null 2>&1; printf '#!/bin/sh\nexit 1\n' > "$W/origin.git/hooks/pre-receive"; chmod +x "$W/origin.git/hooks/pre-receive"
H4=$(newhead); red headers; tick > "$W/out4" 2>&1
grep -q '^o/r PR 1 autofix-fail push' "$W/out4" && ok "TP-4 refused push prints autofix-fail push" || no "TP-4 push stdout: $(cat "$W/out4")"
eq "TP-4 refused push: no AUTOFIX" "$(recs)" 0
nowt "TP-4 push"
rm -f "$W/origin.git/hooks/pre-receive"; reset; echo true > "$W/fork"; tick > "$W/out5" 2>&1
grep -q '^o/r PR 1 autofix-skip fork' "$W/out5" && ok "TP-4 fork PR skipped" || no "TP-4 fork stdout: $(cat "$W/out5")"
eq "TP-4 fork: head untouched" "$(newhead)" "$H4"
echo false > "$W/fork"; reset; cfg off; mkdir -p "$W/shim"; printf '#!/bin/sh\necho called >> "%s/git.calls"\nexec %s "$@"\n' "$W" "$(command -v git)" > "$W/shim/git"; chmod +x "$W/shim/git"
PATH="$W/shim:$PATH" tick > "$W/out6" 2>&1
[ ! -e "$W/git.calls" ] && ok "TP-4 mode off: no git call" || no "TP-4 mode off made git calls"
eq "TP-4 mode off: head untouched" "$(newhead)" "$H4"
cfg on; reset; red "ci-ok"; tick > "$W/out7" 2>&1
eq "TP-4 other check red: head untouched" "$(newhead)" "$H4"
reset; red headers; tick autofix > "$W/out8" 2>&1
eq "TP-4 autofix verb alone pushes one commit" "$(git -C "$W/origin.git" log pr --format=%s -1 | grep -c '(AUTOFIX)')" 1
nowt TP-4
echo "pass=$pass fail=$fail"
[ "$fail" = 0 ]
