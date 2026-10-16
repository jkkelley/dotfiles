# PB-intake - playbook for intake nodes N1 to N10

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [N1 - claim](#n1---claim)
- [N2 - worktree-branch](#n2---worktree-branch)
- [N3 - start-ticket](#n3---start-ticket)
- [N4 - build](#n4---build)
- [N5 - verify](#n5---verify)
- [N6 - open-pr](#n6---open-pr)
- [N7 - close-out](#n7---close-out)
- [N8 - ci](#n8---ci)
- [N9 - merge](#n9---merge)
- [N10 - cleanup](#n10---cleanup)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

Built to docs/design/dag-state-nodes.spec.xml. One H3 per node; the node blocks are rewritten by the DAG verbs, never by hand.

<!-- dag:node:N1:begin -->
### N1 - claim

**Input**

- ticket id, dag.json
- after: none; parallel: per ticket

**Steps**

1. Run `claude/workflow/dag/bin/dag-take.sh` for node N1.
2. Retry up to 3 times on failure (idempotent, safe to rerun); then DG-FAILED and DG-HANDOFF.
3. Serial rule: The run dir must exist before any node.

**Output**

- state.json, nodes.lock/, run lock

**Proofs**

- [ ] State validates against state.schema.json: validator exit 0 in ledger row init
- [ ] Design hash pinned: design.sha256 equals sha256 of nodes.lock/
- [ ] Ticket title recorded in full: ticket.title non-empty in state.json
<!-- dag:node:N1:end -->

<!-- dag:node:N2:begin -->
### N2 - worktree-branch

**Input**

- state.json
- after: N1; parallel: per ticket

**Steps**

1. Run `claude/workflow/dag/bin/dag-take.sh` for node N2.
2. Retry up to 3 times on failure (idempotent, safe to rerun); then DG-FAILED and DG-HANDOFF.
3. Serial rule: Every later node works inside this worktree.

**Output**

- worktree path, branch, lease in state

**Proofs**

- [ ] Lease held: slot.sh status shows the holder
- [ ] Branch is a new feature branch off base_branch: git rev-parse --abbrev-ref HEAD in the worktree equals state branch
<!-- dag:node:N2:end -->

<!-- dag:node:N3:begin -->
### N3 - start-ticket

**Input**

- worktree
- after: N2; parallel: per ticket

**Steps**

1. Run `claude/workflow/dag/bin/dag-take.sh` for node N3.
2. Retry up to 3 times on failure (idempotent, safe to rerun); then DG-FAILED and DG-HANDOFF.
3. Serial rule: None.

**Output**

- ticket in-progress

**Proofs**

- [ ] Ticket status in-progress: work-order.sh show --json status field
<!-- dag:node:N3:end -->

<!-- dag:node:N4:begin -->
### N4 - build

**Input**

- ticket, bundle docs
- after: N3; parallel: per file-set

**Steps**

1. Run `claude/workflow/bin/workflow-spawn.sh` for node N4.
2. Retry up to 3 times on failure (idempotent, safe to rerun); then DG-FAILED and DG-HANDOFF.
3. Serial rule: None.

**Output**

- commits on the branch

**Proofs**

- [ ] Every acceptance criterion has a proof: proof row per criterion in state.json
- [ ] Commits touch only the declared files: git diff --name-only against touches
<!-- dag:node:N4:end -->

<!-- dag:node:N5:begin -->
### N5 - verify

**Input**

- branch diff
- after: N4; parallel: none

**Steps**

1. Run `claude/workflow/tools/ci-select.sh` for node N5.
2. Retry up to 3 times on failure (idempotent, safe to rerun); then DG-FAILED and DG-HANDOFF.
3. Serial rule: None.

**Output**

- verify.json

**Proofs**

- [ ] Only the touched suite ran: verify.json lists the suite and exit 0
<!-- dag:node:N5:end -->

<!-- dag:node:N6:begin -->
### N6 - open-pr

**Input**

- green verify.json
- after: N5; parallel: none

**Steps**

1. Run `claude/workflow/dag/bin/dag-ship.sh` for node N6.
2. Retry up to 0 times on failure (not idempotent, never rerun by hand); then DG-FAILED and DG-HANDOFF.
3. Serial rule: submit must precede done.

**Output**

- PR number, ticket in-review

**Proofs**

- [ ] PR exists: gh pr view number matches state pr.number
- [ ] PR body has no agent footer: grep for the footer exits 1
<!-- dag:node:N6:end -->

<!-- dag:node:N7:begin -->
### N7 - close-out

**Input**

- PR number
- after: N6; parallel: none

**Steps**

1. Run `claude/workflow/dag/bin/dag-ship.sh` for node N7.
2. Retry up to 0 times on failure (not idempotent, never rerun by hand); then DG-FAILED and DG-HANDOFF.
3. Serial rule: Rides the same PR, after submit.

**Output**

- ticket archived, hydration entry, pushed

**Proofs**

- [ ] Ticket done and archived: work-order.sh show status done
- [ ] Pushed to the PR branch: git rev-parse HEAD equals gh pr view headRefOid
<!-- dag:node:N7:end -->

<!-- dag:node:N8:begin -->
### N8 - ci

**Input**

- PR
- after: N7; parallel: none

**Steps**

1. Run `claude/workflow/dag/bin/dag-ci.sh` for node N8.
2. Retry up to 3 times on failure (idempotent, safe to rerun); then DG-FAILED and DG-HANDOFF.
3. Serial rule: Intended wait: CI time.

**Output**

- gate job results

**Proofs**

- [ ] Every required check green: gh pr checks lists each required_checks name as pass
<!-- dag:node:N8:end -->

<!-- dag:node:N9:begin -->
### N9 - merge

**Input**

- green CI, design approval record
- after: N8; parallel: none

**Steps**

1. Run `claude/workflow/dag/bin/dag-merge.sh` for node N9.
2. Retry up to 0 times on failure (not idempotent, never rerun by hand); then DG-FAILED and DG-HANDOFF.
3. Serial rule: None.

**Output**

- merge commit

**Proofs**

- [ ] Approval on record: file in approval_dir names the design id and version
- [ ] Merged: gh pr view state MERGED
<!-- dag:node:N9:end -->

<!-- dag:node:N10:begin -->
### N10 - cleanup

**Input**

- merged PR
- after: N9; parallel: none

**Steps**

1. Run `claude/workflow/dag/bin/dag-ship.sh` for node N10.
2. Retry up to 3 times on failure (idempotent, safe to rerun); then DG-FAILED and DG-HANDOFF.
3. Serial rule: None.

**Output**

- clean machine, archived state

**Proofs**

- [ ] Branch gone local and remote: git branch --list and ls-remote print nothing
- [ ] Lease released and worktree removed: slot.sh status shows free; path absent
- [ ] State archived: run dir moved under archive/ with DG-COMPLETE in the ledger
<!-- dag:node:N10:end -->
