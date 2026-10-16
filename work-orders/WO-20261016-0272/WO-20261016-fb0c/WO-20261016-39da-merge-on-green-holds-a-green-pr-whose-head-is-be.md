---
{
  "id": "WO-20261016-39da",
  "slug": "merge-on-green-holds-a-green-pr-whose-head-is-be",
  "title": "merge-on-green holds a green PR whose head is behind its base branch head, code STALE-BASE (RR-orch-15)",
  "type": "feature",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T08:49:40+00:00",
  "parent": "WO-20261016-fb0c",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "infra-design7 cut for ORD-0830 RR-orch-15 and ORD-0832 B1; design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-448e",
    "WO-20261016-fb99"
  ],
  "blocks": [
    "WO-20261016-7f26",
    "WO-20261016-ac25"
  ],
  "ac_checks": [
    {
      "index": 1,
      "command": "make -C claude/workflow pr-flow-test CASES=\"ci-template\"",
      "exit": 0,
      "expect": "ok  ci-template"
    },
    {
      "index": 2,
      "command": "bash -c bash\\ claude/workflow/pr-flow/bin/pr-flow-ci-render.sh\\ --template\\ merge-on-green\\ --set\\ \\'WORKFLOWS=\\[\\\"skill\\ PR\\ gate\\\"\\,\\\"skill\\ PR\\ intent\\\"\\,\\\"rolodex\\ check\\\"\\,\\\"a2a\\ lint\\\"\\]\\'\\ --set\\ \\'REQUIRED_CHECK=what\\ has\\ to\\ run\\'\\ --set\\ DISPATCH=skill-publish.yml\\ \\|\\ diff\\ -\\ .github/workflows/merge-on-green.yml",
      "exit": 0,
      "expect": null
    },
    {
      "index": 3,
      "command": "bash -c python3\\ -c\\ \\'import\\ xml.dom.minidom\\,sys\\;\\ xml.dom.minidom.parse\\(sys.argv\\[1\\]\\)\\'\\ claude/workflow/docs/pr-process/pr-process.spec.xml\\ \\&\\&\\ grep\\ -c\\ \\'value=\\\"STALE-BASE\\\"\\'\\ claude/workflow/docs/pr-process/pr-process.spec.xml",
      "exit": 0,
      "expect": "^1$"
    },
    {
      "index": 4,
      "command": "make -C claude/workflow pr-flow-lint",
      "exit": 0,
      "expect": null
    },
    {
      "index": 5,
      "command": "bash -c \\!\\ git\\ diff\\ --name-only\\ origin/main...HEAD\\ \\|\\ grep\\ -vE\\ \\'\\^\\(work-orders/\\|\\\\.github/workflows/merge-on-green\\\\.yml\\|claude/workflow/\\(pr-flow/\\(templates/merge-on-green\\\\.yml\\|tests/ci-template\\\\.test\\\\.sh\\)\\|docs/pr-process/pr-process\\\\.\\(md\\|spec\\\\.xml\\)\\)\\)\\$\\'",
      "exit": 0,
      "expect": null
    }
  ],
  "provides": [],
  "labels": [
    "line:inbox-triage"
  ]
}
---

# WO-20261016-39da - merge-on-green holds a green PR whose head is behind its base branch head, code STALE-BASE (RR-orch-15)

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

merge-on-green merges a PR the moment its checks are green, even when those checks ran against a base older than the base branch head, so code lands on main that no CI ran against main.

## Owner words

> RR-orch-15: no branch protection gate. The merge-on-green Action refuses a PR whose last green run tested a base older than main head and runs gh pr update-branch instead, which starts a fresh run; code STALE-BASE on the bus.

## Context

Inventory: claude/workflow/pr-flow/templates/merge-on-green.yml is the source; .github/workflows/merge-on-green.yml is its render (verified 08:45Z: the TP-4 render command reproduces it byte-identical). tests/ci-template.test.sh extracts the script between the markers '# >>> merge-on-green' and '# <<< merge-on-green' and runs it against a stub gh whose unknown calls exit 9.

Split, fact not preference: a push made with GITHUB_TOKEN starts no pull_request run (GitHub's recursion guard, already the breadcrumb at the top of the template for merges), so gh pr update-branch run by the Action would leave a head with no checks and merge-on-green would never fire again. The Action therefore holds and logs STALE-BASE; the update-branch that starts the fresh run, and the STALE-BASE record on the bus, come from the local pr-flow sweep with the owner's token (the sibling RR-orch-15 sweep ticket). GitHub runners cannot reach the local bus (breadcrumb in claude/workflow/timing/ci-events.sh).

Stale means GitHub compare base...head reports behind_by greater than 0: the base branch holds commits the head does not.

## Scope

**In**

- touches: claude/workflow/pr-flow/templates/merge-on-green.yml
- touches: .github/workflows/merge-on-green.yml (rendered, never hand edited)
- touches: claude/workflow/pr-flow/tests/ci-template.test.sh
- touches: claude/workflow/docs/pr-process/pr-process.md
- touches: claude/workflow/docs/pr-process/pr-process.spec.xml
- touches (generated, written only by work-order.sh start/submit/done, never by hand): work-orders/INDEX.md, this ticket file and its archive path, the parent epic README.md
- step: start only after the restore ticket and WO-20261016-fb99 are done and merged (both touch the pr-process docs); branch from origin/main
- step: template, inside the markers, directly after the REQUIRED_CHECK jq line and before the line that sets before=, insert exactly two lines: behind="$(retry gh api "repos/$REPO/compare/$baseref...$HEAD_SHA" --jq .behind_by)" || { say 423 "blocked: gh failed 3 times comparing with $baseref"; exit 1; } and then [ "$behind" = 0 ] || { say STALE-BASE "held: head $behind behind $baseref; the pr-flow sweep runs update-branch"; exit 0; }
- step: template header comment: one gate bullet after the REQUIRED_CHECK bullet: '- head not behind its base (compare behind_by 0); else hold with STALE-BASE, and the local pr-flow sweep runs update-branch with the owner token, because a GITHUB_TOKEN push starts no run (RR-orch-15)'
- step: render: bash claude/workflow/pr-flow/bin/pr-flow-ci-render.sh --template merge-on-green --set 'WORKFLOWS=["skill PR gate","skill PR intent","rolodex check","a2a lint"]' --set 'REQUIRED_CHECK=what has to run' --set DISPATCH=skill-publish.yml --out .github/workflows/merge-on-green.yml
- step: ci-template.test.sh: the stub gh gains the case "api repos/o/r/compare/"*) [ "${F_CMP_FAIL:-}" = 1 ] && exit 1; echo "${F_BEHIND:-0}" ;; and three run cases: F_BEHIND=2 expects no merge and output matching '^STALE-BASE pr=7 .*held: head 2 behind main'; F_BEHIND=0 expects the merge and '^200 pr=7'; F_CMP_FAIL=1 expects no merge, rc 1 and '^423 pr=7 .*comparing with main'; every existing case keeps passing (the default F_BEHIND 0)
- step: pr-process.md section 9: row after the RERUN row, exactly: | STALE-BASE | ci.stale-base | a green PR whose head is behind its base head; merge-on-green holds it, the sweep runs update-branch once per base sha | nobody; CI runs on the new head |. pr-process.spec.xml codes, after the RERUN code: <code value="STALE-BASE" kind="ci.stale-base" acts="none; the sweep refreshes the head and CI runs on it"/>
- step: run TP-1 to TP-5 and the AC checks only; CI runs the rest
- tool: path:claude/workflow/pr-flow/bin/pr-flow-ci-render.sh - on main; fallback: missing: stop with DESIGN-GAP

**Out - non-goals**

- gh pr update-branch inside the Action: a GITHUB_TOKEN push starts no run; the sweep ticket owns it
- a branch protection rule or required-up-to-date setting (owner: no branch protection gate)
- pr-flow-consume.sh, pr-flow.json, the record schema: the sweep ticket owns them
- work-orders/INDEX.md and epic READMEs by hand or by git add: they are ignored generated views
- waiting on CI or merging: push, open the PR, write the result, leave (ORD-0542 O2)
- any file not named under In: stop with DESIGN-GAP and hand it back to infra-design (ORD-0548, item 30)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* the hold, the merge and the compare outage cases pass with every existing case
  - check: `make -C claude/workflow pr-flow-test CASES="ci-template"` exit 0 expect /ok ci-template/
- [ ] `AC-H2` *(human)* the live workflow is the render of the template
  - check: `bash -c bash\ claude/workflow/pr-flow/bin/pr-flow-ci-render.sh\ --template\ merge-on-green\ --set\ \'WORKFLOWS=\[\"skill\ PR\ gate\"\,\"skill\ PR\ intent\"\,\"rolodex\ check\"\,\"a2a\ lint\"\]\'\ --set\ \'REQUIRED_CHECK=what\ has\ to\ run\'\ --set\ DISPATCH=skill-publish.yml\ \|\ diff\ -\ .github/workflows/merge-on-green.yml` exit 0
- [ ] `AC-H3` *(human)* the spec parses and carries STALE-BASE once
  - check: `bash -c python3\ -c\ \'import\ xml.dom.minidom\,sys\;\ xml.dom.minidom.parse\(sys.argv\[1\]\)\'\ claude/workflow/docs/pr-process/pr-process.spec.xml\ \&\&\ grep\ -c\ \'value=\"STALE-BASE\"\'\ claude/workflow/docs/pr-process/pr-process.spec.xml` exit 0 expect /^1$/
- [ ] `AC-H4` *(human)* pr-flow scripts stay shellcheck clean
  - check: `make -C claude/workflow pr-flow-lint` exit 0
- [ ] `AC-H5` *(human)* the diff holds only In files and generated work-orders files
  - check: `bash -c \!\ git\ diff\ --name-only\ origin/main...HEAD\ \|\ grep\ -vE\ \'\^\(work-orders/\|\\.github/workflows/merge-on-green\\.yml\|claude/workflow/\(pr-flow/\(templates/merge-on-green\\.yml\|tests/ci-template\\.test\\.sh\)\|docs/pr-process/pr-process\\.\(md\|spec\\.xml\)\)\)\$\'` exit 0

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

the merge-on-green template's stale-base hold, its rendered copy in .github/workflows/merge-on-green.yml, and the STALE-BASE code in the pr-process status map

**Cases**

- `TP-1`
  - intent: a PR whose green run tested a base older than its base branch head must never merge; the merge would land code no CI ever ran against main (RR-orch-15, ORD-0830)
  - command: `make -C claude/workflow pr-flow-test CASES="ci-template"`
  - expected: exit 0; prints `ok  ci-template`; with the stub compare answering behind_by 2 the script prints a line starting `STALE-BASE pr=7` containing `held: head 2 behind main`, makes no `gh pr merge` call and exits 0
- `TP-2`
  - intent: an up-to-date green PR still merges at once (item 21)
  - command: `make -C claude/workflow pr-flow-test CASES="ci-template"`
  - expected: exit 0; with behind_by 0 the script prints `200 pr=7` and calls `gh pr merge 7` once
- `TP-3`
  - intent: a GitHub outage on the compare call is retried 3 times and blocks loudly, never merges blind (item 28)
  - command: `make -C claude/workflow pr-flow-test CASES="ci-template"`
  - expected: exit 0; with the stub compare failing the script prints `423 pr=7` containing `comparing with main`, exits 1, and makes no `gh pr merge` call
- `TP-4`
  - intent: the live workflow is the rendered template, never a hand edit
  - command: `bash -c "bash claude/workflow/pr-flow/bin/pr-flow-ci-render.sh --template merge-on-green --set 'WORKFLOWS=[\"skill PR gate\",\"skill PR intent\",\"rolodex check\",\"a2a lint\"]' --set 'REQUIRED_CHECK=what has to run' --set DISPATCH=skill-publish.yml | diff - .github/workflows/merge-on-green.yml"`
  - expected: exit 0, no output
- `TP-5`
  - intent: the status code map names STALE-BASE once and the spec parses (item 29)
  - command: `bash -c "python3 -c 'import xml.dom.minidom,sys; xml.dom.minidom.parse(sys.argv[1])' claude/workflow/docs/pr-process/pr-process.spec.xml && grep -c 'value=\"STALE-BASE\"' claude/workflow/docs/pr-process/pr-process.spec.xml"`
  - expected: exit 0; prints `1`

**Isolation**

- runtime: podman
- image: `docker.io/library/debian:bookworm-slim@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251` (debian:bookworm-slim, base of localhost/dotfiles-workflow-test:1)

**Out of scope - CI covers**

- the live Action on a real PR: the RR-orch-15 test ticket's UAT case
- the full claude/workflow suite: CI runs it

## Assumptions

1. whole-change fallback: revert this one commit; merge-on-green returns to merging on green alone, and the sweep's backstop keeps merging

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
