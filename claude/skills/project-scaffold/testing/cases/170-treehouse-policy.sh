#!/usr/bin/env bash
# A scaffolded project names exactly one source for a workspace.
#
# Decision 19 kept the treehouse pool user-level at ~/.treehouse/<repo>-<hash>/
# and rejected an in-project pool. The cost of that decision was accepted rather
# than dismissed: the pool name is a hash directory, it cannot be reconstructed by
# hand, and it does not say where its repository lives. The decision recorded that
# the cost is paid with one paragraph in this template and with `treehouse status`
# - so this paragraph is the payment, and a template that ships without it leaves
# an agent to invent `git worktree add` in the repository, which is the thing the
# decision rejected.
#
# The in-project half is the assertion that earns its keep. An agent that reaches
# for `--root .` gets a pool of build cache inside the working tree, which is bound
# into every container under Rule 14, taken as build context by `podman build .`,
# and staged by `git add -A`. None of that fails loudly; it just makes every
# container run slower and every commit riskier.
#
# Nothing here reproduces treehouse's flags. The tool went v1.8.0 to v2.3.0 in a
# morning, so a copy of its interface written into a template is wrong within a
# release and nothing catches it - the pointer is the deliverable, not a manual.
CASE_NAME=170-treehouse-policy
source "${SKILL:-/skill}/testing/assert.sh"

p=$(scaffolded_project)

assert_contains "$p/CLAUDE.md" "## Where your workspace comes from" \
  "CLAUDE.md carries the treehouse policy section"

# One source, named as one. "A workspace usually comes from the pool" leaves the
# other options open, which is the state this section exists to close.
assert_contains "$p/CLAUDE.md" "One source: the treehouse pool at" \
  "the pool is named as the single source"

assert_contains "$p/CLAUDE.md" '~/.treehouse/<repo>-<hash>/' \
  "the pool path is the user-level one from decision 19"

# The two things an agent reaches for instead, refused by name. A hand-rolled
# worktree is the reflex; a second in-project pool is what `--root .` gives you.
assert_contains "$p/CLAUDE.md" "Never hand-roll a \`git worktree add\`" \
  "hand-rolled worktrees are refused"

assert_contains "$p/CLAUDE.md" "never create a second pool inside the repository" \
  "an in-project pool is refused"

# The pointer that pays for the hash directory being unreadable.
assert_contains "$p/CLAUDE.md" "\`treehouse status\`" \
  "treehouse status is named as the live map"

# A pointer, not a manual. Flags copied into the template go stale silently, and
# an agent following a stale flag gets an error that looks like a broken pool.
assert_not_contains "$p/CLAUDE.md" "destroy --force" \
  "no treehouse flags are reproduced in the template"

finish
