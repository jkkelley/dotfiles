#!/usr/bin/env bash
# rolodex: header drafted by scripts/rolodex.py headers - correct any line that is wrong
# name: 450-code-dir-worktree.sh
# purpose: Assert check, evidence and approve run a cross-repo ticket in a detached worktree of the code repo origin, never the --code-dir checkout as it stands (WO-20261016-318d).
# inputs: env SKILL (skill root, default /skill); sourced assert.sh helpers
# outputs: exit code 0 when every assertion passes, assertion lines on stdout
# writes-to: scratch project, code-repo and bare-origin dirs under mktemp, plus a fake gh script
# cleanup: the sandbox container is discarded; nothing outside the mktemp dirs is touched
# The reason this case exists.
#
# WO-20261016-64f2 F44: done ran in the wrong tree, and an old copy of the code
# checkout passed approve for tools not on main. The marker file exists only on
# branch feat/x of the origin and, untracked, in the checkout's working tree, so
# a check that passes proves which tree it ran in.
source "${SKILL:-/skill}/testing/assert.sh"

d=$(git_project)
code=$(git_project)
bare="${code}.git"
git -C "$code" checkout -q -b feat/x
printf 'x\n' >"$code/marker"
git -C "$code" add -A && git -C "$code" commit -qm "marker" && git -C "$code" push -q origin feat/x
git -C "$code" checkout -q main
printf 'x\n' >"$code/marker" # untracked in the checkout, on no origin ref but feat/x's content
git -C "$code" fetch -q origin
fake_origin "$code" https://github.com/acme/code.git

fakegh=$(mktemp -d)
for st in OPEN MERGED; do
  printf '#!/usr/bin/env bash\nprintf '"'"'{"state":"%s","headRefName":"feat/x"}\\n'"'"'\n' "$st" >"$fakegh/gh-$st"
  chmod +x "$fakegh/gh-$st"
done

err() { wo "$@" --json 2>&1 | jq -r '.error // .status'; }
has() { if [[ $1 == "$2" ]]; then _pass "$3"; else _fail "$3" "wanted $2" "got: ${1:0:200}"; fi; }
mk() { # mk <title>
  wo new --project "$d" --title "$1" --type feature --problem P --top-level --out X --ac "marker" --ac-check "test -f marker" --ac-exit 0 --repo acme/code >/dev/null
  wo list --project "$d" --json | jq -r --arg t "$1" '.[] | select(.title == $t) | .id'
}
setpr() { # setpr <id> <n> - a scratch ticket gets an open PR number
  local f; f=$(find "$d/work-orders" -name "$1*.md" | head -n 1)
  sed -i "s/\"pr\": null/\"pr\": $2/" "$f"
}
wtcount() { git -C "$code" worktree list | wc -l | tr -d ' '; }
ready() { wo approve --project "$d" --id "$1" --no-lavish --reason r --code-dir "$code" >/dev/null; wo start --project "$d" --id "$1" >/dev/null; }

a=$(mk "Pr null"); ready "$a"
out=$(wo check --project "$d" --id "$a" --code-dir "$code" 2>&1 || true)
has "$(grep -c 'AC-FAIL 1' <<<"$out")" 1 "(a) .pr null checks origin/main, not the checkout's working tree"
has "$(wtcount)" 1 "(e) no worktree left after (a)"
out=$(wo check --project "$d" --id "$a" --code-dir "$code" --code-ref origin/feat/x 2>&1 || true)
has "$(grep -c 'AC-PASS 1' <<<"$out")" 1 "(b) --code-ref origin/feat/x passes"
has "$(wtcount)" 1 "(e) no worktree left after (b)"

b=$(mk "Pr open"); ready "$b"; setpr "$b" 7
out=$(GH="$fakegh/gh-OPEN" wo check --project "$d" --id "$b" --code-dir "$code" 2>&1 || true)
has "$(grep -c 'AC-PASS 1' <<<"$out")" 1 "(c) an OPEN pr checks the pr head"
out=$(GH="$fakegh/gh-MERGED" wo check --project "$d" --id "$b" --code-dir "$code" 2>&1 || true)
has "$(grep -c 'AC-FAIL 1' <<<"$out")" 1 "(c) a MERGED pr checks origin/main"
has "$(wtcount)" 1 "(e) no worktree left after (c)"

code2=$(git_project)
fake_origin "$code2" https://github.com/acme/code.git
git -C "$code2" config --unset-all url."${code2}.git".insteadOf
git -C "$code2" config --add url."${code2}-gone.git".insteadOf https://github.com/acme/code.git
has "$(err check --project "$d" --id "$a" --code-dir "$code2")" code_fetch_failed "(d) a fetch that fails 3 times is code_fetch_failed"

c=$(mk "Evidence"); ready "$c"
has "$(err evidence --project "$d" --id "$c" --match marker --observed seen)" code_dir_required "(f) evidence without --code-dir is code_dir_required"
wo evidence --project "$d" --id "$c" --match marker --observed seen --code-dir "$code" --code-ref origin/feat/x >/dev/null
f=$(find "$d/work-orders" -name "$c*.md" | head -n 1)
has "$(grep -cE '\(at acme/code@[0-9a-f]{12}\)' "$f")" 1 "(f) evidence names the code commit"
has "$(wtcount)" 1 "(e) no worktree left after (f)"

n=$(git_project)
printf 'x\n' >"$n/marker"
wo new --project "$n" --title "No repo" --type feature --problem P --top-level --out X --ac "marker" --ac-check "test -f marker" --ac-exit 0 >/dev/null
g=$(wo list --project "$n" --json | jq -r '.[0].id')
wo approve --project "$n" --id "$g" --no-lavish --reason r >/dev/null
wo start --project "$n" --id "$g" >/dev/null
git -C "$n" remote remove origin
run 0 "(g) a ticket with .repo null checks in the project, no origin needed" wo check --project "$n" --id "$g"
finish
