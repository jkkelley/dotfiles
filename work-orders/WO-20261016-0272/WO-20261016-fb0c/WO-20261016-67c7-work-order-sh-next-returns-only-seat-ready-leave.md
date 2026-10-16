---
{
  "id": "WO-20261016-67c7",
  "slug": "work-order-sh-next-returns-only-seat-ready-leave",
  "title": "work-order.sh next returns only seat-ready leaves: no epics, no merged PR or branch, --line NAME keeps tickets labeled line:NAME; set verb writes labels (ORD-0932 Q2)",
  "type": "feature",
  "status": "in-progress",
  "priority": "p0",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T09:43:18+00:00",
  "parent": "WO-20261016-fb0c",
  "branch": "feat/work-order-sh-next-returns-only-seat-ready-leave",
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "infra-design11 cut for ORD-0932-next Q2 and the ORD-0830 RR-orch-14 DESIGN-GAPs; design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": [
    "WO-20261016-f57d",
    "WO-20261016-8a35"
  ],
  "ac_checks": [
    {
      "index": 1,
      "command": "bash claude/skills/work-order/testing/run-tests.sh",
      "exit": 0,
      "expect": "all cases passed"
    },
    {
      "index": 2,
      "command": "grep -c 'set) cmd_set' claude/skills/work-order/scripts/work-order.sh",
      "exit": 0,
      "expect": "^1$"
    },
    {
      "index": 3,
      "command": "grep -c -- '--line) ' claude/skills/work-order/scripts/work-order.sh",
      "exit": 0,
      "expect": "^1$"
    },
    {
      "index": 4,
      "command": "bash -c '! git diff --name-only origin/main...HEAD | grep -vE \"^(work-orders/.*|claude/skills/work-order/scripts/work-order[.]sh|claude/skills/work-order/testing/cases/350-next-seat-ready[.]sh)$\"'",
      "exit": 0,
      "expect": null
    }
  ],
  "provides": [
    "claude/skills/work-order/testing/cases/350-next-seat-ready.sh",
    "set"
  ]
}
---

# WO-20261016-67c7 - work-order.sh next returns only seat-ready leaves: no epics, no merged PR or branch, --line NAME keeps tickets labeled line:NAME; set verb writes labels (ORD-0932 Q2)

## Contents

- Problem
- Owner words
- Context
- Scope
- Degrees of freedom
- Acceptance criteria
- Test plan
- Assumptions
- Open questions
- Notes
- Outcome

## Problem

The orchestrator seats from zwo next, and next lists every ready ticket whose deps are done: epics (WO-20261016-fb0c, WO-20261016-ebe4, WO-20261016-1703, WO-20261016-6e8e on 2026-10-16), tickets whose PR already merged, and in a shared project the 2026-08 Venture 1 business tickets that are not line work. A seat started on any of them burns a slot on nothing. The queue the line reads must hold only seat-ready leaves of its own line.

## Owner words

> get this code merged the fuck in, dead code is shit, it sitting under agents is stupid (item 21)

> so its re-usable, add to it, makefiles, dont' be a crackhead and one off shit all the time, if we need to do so (item 30)

> these fucks are making shit up because they don't have clear instructions, thats fuckd, don't give them freedom and let them create this shit, it should already be ready for them (item 30)

## Context

Order ORD-0932-next Q2 (L0 top, first): tooling ticket: zwo next returns only seat-ready leaves: excludes tickets with children, tickets whose PR or branch is merged (the stale-merged verb), and with --line <name> only tickets labeled for that line. Every build-order ticket gets its line label by script. The orchestrator seats from zwo next --line inbox-triage. 2026-08 Venture 1 business tickets stay untouched (not cancelled); the line label keeps them out of the queue (Q3). Standing rule Q4: design seats keep a buffer of at least 6 seat-ready leaves measured by zwo next --line.

Fixed by this design. (1) Frontmatter key labels: an array of strings, sorted and unique; absent reads as []. Label syntax ^[a-z0-9][a-z0-9:._-]*$, else exit 2 bad_label. A line label is line:<name>. (2) new gains --label L (repeatable); new --parent P first copies P labels, then adds --label values. (3) New verb: work-order.sh set [--project DIR] (--id WO-... | --tree WO-...) [--add-label L]... [--remove-label L]... [--json]. --tree applies to the ticket and every non-archived descendant by parent link. set writes only .labels: never status, scope, updated or any other key, so it cannot conflict with a close-out on another branch. A ticket whose labels already match is not rewritten (byte-identical file). An archived ticket named by --id exits 3 archived; under --tree it is skipped. At least one --add-label or --remove-label, else exit 2 usage. Text output: one line per changed ticket LABELED <id> <labels comma joined>; --json: an array of {id,labels,changed}. reindex runs once at the end. (4) next keeps a ticket only when: status ready, every dep done, not archived, no ticket (archived or not) names it as parent, with --line N its labels contain line:N, and it is not merged. Merged is the stale-merged lookup: refactor the per-ticket body of cmd_stale_merged into merged_info <file> <repo> (prints the info JSON, or nothing when not merged) and call it from both verbs, so the two never disagree; gh is called only for candidates whose pr or branch is set. gh failing 3 times: next dies exit 4 gh_failed naming the call. next --offline skips the merged check and prints on stderr: next: merged check skipped (--offline). (5) next --json objects gain labels. (6) Breadcrumb comment at cmd_next and cmd_set citing ORD-0932 Q2 and the four epics above.

Rejected: deriving the line from the parent tree at read time, because the owner order says the label is written by script and a ticket moves between epics by link; rejected: a new script beside work-order.sh, because item 30 says a need is met by a verb on the existing tool. Cost: one gh call per candidate with a pr or branch per run. Labeling the existing tickets is its own ticket that depends on this one.

## Scope

**In**

- touches: claude/skills/work-order/scripts/work-order.sh (cmd_next filters and --line/--offline flags; cmd_set and dispatch line 'set) cmd_set ;;'; merged_info factored out of cmd_stale_merged; new --label and parent label inheritance in cmd_new; usage block lines for next, set and new --label; the unknown_command verb list; breadcrumbs)
- touches: claude/skills/work-order/testing/cases/350-next-seat-ready.sh (new, gh stubbed on PATH as in 320: epic with a ready child -> child listed, epic not; epic whose only child is archived done -> not listed; ready with pr MERGED -> not listed, pr OPEN -> listed; ready with branch merged -> not listed; --line inbox-triage keeps line:inbox-triage only, drops unlabeled and line:other; --json carries labels; new --parent inherits labels and --label adds; set --add-label twice leaves git diff --quiet on the second run; set --tree labels descendants and skips archived; set keeps status and updated; bad label exit 2 bad_label; archived --id exit 3 archived; gh stub failing -> next exit 4 gh_failed; next --offline exit 0 with the skipped warning on stderr; git status --porcelain empty after next)
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: branch from origin/main in your own worktree; write exactly the two files above to the design in Context
- step: run `bash claude/skills/work-order/testing/run-tests.sh` and the AC checks; commit 'feat(work-order): next returns seat-ready leaves, --line and the set verb (ORD-0932 Q2)' with the ticket id; the PR body ends with 'Bump: work-order=minor'
- tool: cmd:git, cmd:jq, cmd:podman, cmd:gh - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then FB-003 (push with git, park the PR step with a note) and A2A-003 with the output
- tool: path:claude/skills/work-order/testing/run-tests.sh - on main; fallback: its image fails to build: stop with ENV-MISSING podman

**Out - non-goals**

- labeling existing tickets: WO ticket "Label every inbox-triage build-order ticket line:inbox-triage" depends on this one
- the orchestrator seating command and zwo refresh: the orchestrator owns them
- SKILL.md, references/lifecycle.md and testing/SOP.md: WO-20261016-2eb1 owns them and runs after this ticket; no doc edits here
- work-orders/INDEX.md and epic READMEs by hand or by git add: they are ignored generated views
- waiting on CI or merging: push, open the PR, write the result, leave (ORD-0542 O2)
- any file not named under In: stop with DESIGN-GAP and hand it back to infra-design (ORD-0548, item 30)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* case 350 and the whole skill suite pass
  - check: `bash claude/skills/work-order/testing/run-tests.sh` exit 0 expect /all cases passed/
- [ ] `AC-H2` *(human)* the set verb is dispatched
  - check: `grep -c 'set) cmd_set' claude/skills/work-order/scripts/work-order.sh` exit 0 expect /^1$/
- [ ] `AC-H3` *(human)* next takes --line
  - check: `grep -c -- '--line) ' claude/skills/work-order/scripts/work-order.sh` exit 0 expect /^1$/
- [ ] `AC-H4` *(human)* the diff holds only In files and generated work-orders files
  - check: `bash -c '! git diff --name-only origin/main...HEAD | grep -vE "^(work-orders/.*|claude/skills/work-order/scripts/work-order[.]sh|claude/skills/work-order/testing/cases/350-next-seat-ready[.]sh)$"'` exit 0

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

work-order.sh next (seat-ready leaves only, --line, --offline) and the new set verb (labels)

**Cases**

- `TP-1`
  - intent: the new case proves the change; a red block means the verb ships broken to every seat that calls it
  - command: `bash claude/skills/work-order/testing/run-tests.sh 2>&1 | sed -n '/350-next-seat-ready.sh/,/checks, [0-9]* failed/p'`
  - expected: exit 0; the block ends with `0 failed`
- `TP-2`
  - intent: the change must not break any other work-order verb
  - command: `bash claude/skills/work-order/testing/run-tests.sh | tail -1`
  - expected: exit 0; the last line starts with `all cases passed:`
- `TP-3`
  - intent: dev gate on real data: next on dotfiles main returns no epic and writes nothing (ORD-0932 Q2)
  - command: `bash -c 'd=$(mktemp -d) && git worktree add -q --detach $d origin/main && ids=$(bash claude/skills/work-order/scripts/work-order.sh next --project $d --json | jq -r ".[].id") && n=0 && for i in $ids; do grep -rlq "\"parent\": \"$i\"" $d/work-orders && n=$((n+1)); done; echo epics=$n; git -C $d status --porcelain | wc -l; git worktree remove --force $d'`
  - expected: exit 0; prints `epics=0` then `0`

**Isolation**

- runtime: podman
- image: `localhost/work-order-test:1`
- build: `bash claude/skills/work-order/testing/run-tests.sh`
- containerfile: `claude/skills/work-order/testing/Containerfile`

**Out of scope - CI covers**

- the full skill suite in skill-pr-gate

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
