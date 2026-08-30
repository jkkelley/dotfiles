#!/usr/bin/env bash
# A scaffolded project names exactly one destination for a document.
#
# Two rules used to answer this question and neither deferred to the other. The
# template said every runbook and playbook lives in local-k8s-docs; living-docs
# says procedures go to <project>/docs/sops/ via docs.sh sop. Both were stated as
# the way it is done, so a document landed wherever the agent had read last, and
# the same procedure could exist in both places without either copy knowing.
#
# Lifetime is the discriminator, and the question has exactly one answer per
# document: would this still be true after this repo is deleted? That is what
# these assertions defend. The failure mode if the arbitration is lost is not a
# broken build - it is two half-populated documentation sets, discovered months
# later by somebody following the wrong one.
#
# The URL assertion is the sharp one. Root CLAUDE.md carries a standing rule that
# environment-specific values become <angle-bracket> placeholders. Somebody
# applying that rule here turns the one pointer to the platform documentation
# into a link to a repository that does not exist, and nothing catches it: an
# agent that cannot find the repo concludes there is nothing there and carries on
# inventing. A literal-string assertion with the owner inside the needle is the
# only thing in the way.
CASE_NAME=150-documentation-lifetime
source "${SKILL:-/skill}/testing/assert.sh"

p=$(scaffolded_project)

assert_contains "$p/CLAUDE.md" "## Hard rule: documentation goes where its lifetime says it goes" \
  "CLAUDE.md carries the documentation-lifetime rule"

# The question itself. Without it the two destinations are a list to choose from
# rather than a decision that has already been made.
assert_contains "$p/CLAUDE.md" "would this still be true after this repo is deleted?" \
  "the lifetime question is the thing that decides"

# One answer per document, stated as such. This is the arbitration: a rule that
# describes both destinations and stops there is the state this replaced.
assert_contains "$p/CLAUDE.md" "every document has exactly one destination" \
  "exactly one destination per document"

# Both destinations, so the question has somewhere to route to. The URL, whole
# and literal - the owner is the part that gets substituted away, so the owner
# has to be inside the needle.
assert_contains "$p/CLAUDE.md" "https://github.com/jkkelley/local-k8s-docs" \
  "the platform destination is literal, with its real owner"

assert_not_contains "$p/CLAUDE.md" "<your-github-username>/local-k8s-docs" \
  "the platform URL was not turned into a placeholder"

assert_contains "$p/CLAUDE.md" "\`docs.sh sop\`" \
  "the in-repo destination names the script that owns it"

# Both words. An agent that reads a rule about "documentation" and is looking for
# where a runbook goes should not have to decide whether the rule covers it.
assert_contains "$p/CLAUDE.md" "Runbooks and playbooks both" \
  "runbooks and playbooks are covered by the same rule"

# Access is a request, not a blocker. An agent that cannot reach the platform
# repository and has not been told to ask will route around it, which is the
# failure this whole rule exists to prevent.
assert_contains "$p/CLAUDE.md" "If you need access to it, ask" \
  "a missing grant is something to ask for, not to work around"

# Follow the format that is there, not a better one. Divergent formats are how a
# single source of truth stops being usable as one.
assert_contains "$p/CLAUDE.md" "in the same format as the ones beside it" \
  "a new document follows the existing format"

# The write-it-if-missing case. This is the one that gets skipped, and skipping
# it is the whole failure mode: the process gets worked out, the task ships, and
# the knowledge never leaves the session it was derived in.
assert_contains "$p/CLAUDE.md" "that process is a document that does not exist yet" \
  "working a process out obliges you to write it down"

# The negative half of the same rule. Stated separately because "write the
# missing one" and "do not invent a parallel one" fail in opposite directions.
assert_contains "$p/CLAUDE.md" "Do not invent a local procedure when a documented one exists" \
  "an existing documented process wins over a local invention"

# The rule this arbitrated away. If the old heading is back, so is the conflict.
assert_not_contains "$p/CLAUDE.md" "## Hard rule: every runbook and playbook lives in one repository" \
  "the unarbitrated one-repository rule is gone"

finish
