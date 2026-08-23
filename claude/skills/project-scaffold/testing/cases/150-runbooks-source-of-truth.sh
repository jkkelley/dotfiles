#!/usr/bin/env bash
# A scaffolded project tells its agent where the operational knowledge lives.
#
# Without this section an agent lands in a fresh repo with no idea that runbooks
# and playbooks exist at all, so it does the reasonable thing and invents a
# procedure. The invented one is never written down, because inventing it did not
# feel like authoring a runbook - it felt like finishing the task. The knowledge
# then lives in a chat log nobody reads again, and the next agent invents a
# different one. Nothing fails; the setup just quietly grows N procedures for one
# job.
#
# The URL assertion is the sharp one, and it is sharp for exactly the reason
# case 140's is. Root CLAUDE.md carries a standing rule that environment-specific
# values become <angle-bracket> placeholders. Somebody applying that rule here
# turns the one pointer to the documentation into a link to a repository that
# does not exist, and nothing catches it: an agent that cannot find the repo
# concludes there is nothing there and carries on inventing. A literal-string
# assertion with the owner inside the needle is the only thing in the way.
CASE_NAME=150-runbooks-source-of-truth
source "${SKILL:-/skill}/testing/assert.sh"

p=$(scaffolded_project)

assert_contains "$p/CLAUDE.md" "## Hard rule: every runbook and playbook lives in one repository" \
  "CLAUDE.md carries the runbooks source-of-truth rule"

# The URL, whole and literal. Not a fragment - the owner is the part that gets
# substituted away, so the owner has to be inside the needle.
assert_contains "$p/CLAUDE.md" "https://github.com/jkkelley/local-k8s-docs" \
  "the docs URL is literal, with its real owner"

assert_not_contains "$p/CLAUDE.md" "<your-github-username>/local-k8s-docs" \
  "the docs URL was not turned into a placeholder"

# Both words. An agent that reads "runbooks" only will look for a runbook, not
# find one, and never think to look for the playbook sitting next to it.
assert_contains "$p/CLAUDE.md" "Runbooks and playbooks both" \
  "both runbooks and playbooks are named as living there"

# Access is a request, not a blocker. An agent that cannot reach the repository
# and has not been told to ask will route around it, which is the failure this
# whole rule exists to prevent.
assert_contains "$p/CLAUDE.md" "If you need access to it, ask" \
  "a missing grant is something to ask for, not to work around"

# Follow the format that is there, not a better one. Divergent formats are how a
# single source of truth stops being usable as one.
assert_contains "$p/CLAUDE.md" "in the same format as the ones beside it" \
  "a new document follows the existing format"

# The write-it-if-missing case. This is the one that gets skipped, and skipping
# it is the whole failure mode: the process gets worked out, the task ships, and
# the knowledge never leaves the session it was derived in.
assert_contains "$p/CLAUDE.md" "that process is now a runbook that does not exist yet" \
  "working a process out obliges you to write it down"

# The negative half of the same rule. Stated separately because "write the
# missing one" and "do not invent a parallel one" fail in opposite directions.
assert_contains "$p/CLAUDE.md" "Do not invent a local procedure when a documented one exists" \
  "an existing documented process wins over a local invention"

finish
