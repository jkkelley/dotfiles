---
{
  "id": "WO-20261016-3201",
  "slug": "gitops-gate-evidence-sh-a-pr-touching-a-deploy-p",
  "title": "gitops-gate-evidence.sh: a PR touching a deploy path is held until its body names its ticket and carries Gate-Dev and Gate-UAT GATE-PASS lines",
  "type": "feature",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T11:50:54+00:00",
  "parent": "WO-20261016-770f",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "infra-design19 cut ORD-1128 K1 and ORD-1140 S3 (brief BR-20261016-infra-design19); design approvals ruled done, ORD-0550 O4; Claude seats never use lavish (global owner rule)",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": [
    "WO-20261016-ae02"
  ],
  "ac_checks": [
    {
      "index": 1,
      "command": "make -C claude/workflow image >/dev/null && podman run --rm --network=none --userns=keep-id -e HOME=/tmp -v \"$PWD:/work:Z\" -w /work localhost/dotfiles-workflow-test:1 bash -c 'bash claude/workflow/gitops-ci/bin/gitops-gate-evidence.sh --help'",
      "exit": 0,
      "expect": "gitops-gate-evidence\\.sh"
    },
    {
      "index": 2,
      "command": "make -C claude/workflow image >/dev/null && podman run --rm --network=none --userns=keep-id -e HOME=/tmp -v \"$PWD:/work:Z\" -w /work localhost/dotfiles-workflow-test:1 bash -c 'd=$(mktemp -d) && printf \"{\\\"defaults\\\":{\\\"evidence\\\":{\\\"ticket_re\\\":\\\"WO-[0-9]{8}-[0-9a-f]{4}\\\",\\\"dev_re\\\":\\\"^Gate-Dev: GATE-PASS dev .+\\\",\\\"uat_re\\\":\\\"^Gate-UAT: GATE-PASS uat .+\\\"}},\\\"repos\\\":{}}\" > $d/c.json && printf \"{\\\"deploy\\\":true}\" > $d/s.json && printf \"Ticket WO-20261016-abcd\\r\\nGate-Dev: GATE-PASS dev line-ops T0-T6\\r\\nGate-UAT: GATE-PASS uat line-ops U1\\r\\n\" > $d/b.md && bash claude/workflow/gitops-ci/bin/gitops-gate-evidence.sh --repo jkkelley/homelab-gitops --select $d/s.json --config $d/c.json --body-file $d/b.md'",
      "exit": 0,
      "expect": "GATE-OK WO-20261016-abcd dev uat"
    },
    {
      "index": 3,
      "command": "make -C claude/workflow image >/dev/null && podman run --rm --network=none --userns=keep-id -e HOME=/tmp -v \"$PWD:/work:Z\" -w /work localhost/dotfiles-workflow-test:1 bash -c 'd=$(mktemp -d) && printf \"{\\\"defaults\\\":{\\\"evidence\\\":{\\\"ticket_re\\\":\\\"WO-[0-9]{8}-[0-9a-f]{4}\\\",\\\"dev_re\\\":\\\"^Gate-Dev: GATE-PASS dev .+\\\",\\\"uat_re\\\":\\\"^Gate-UAT: GATE-PASS uat .+\\\"}},\\\"repos\\\":{}}\" > $d/c.json && printf \"{\\\"deploy\\\":true}\" > $d/s.json && printf \"Ticket WO-20261016-abcd\\nGate-Dev: GATE-PASS dev line-ops T0-T6\\n\" > $d/b.md && bash claude/workflow/gitops-ci/bin/gitops-gate-evidence.sh --repo jkkelley/homelab-gitops --select $d/s.json --config $d/c.json --body-file $d/b.md'",
      "exit": 1,
      "expect": "GATE-MISSING uat"
    },
    {
      "index": 4,
      "command": "make -C claude/workflow image >/dev/null && podman run --rm --network=none --userns=keep-id -e HOME=/tmp -v \"$PWD:/work:Z\" -w /work localhost/dotfiles-workflow-test:1 bash -c 'd=$(mktemp -d) && printf \"{\\\"defaults\\\":{\\\"evidence\\\":{\\\"ticket_re\\\":\\\"WO-[0-9]{8}-[0-9a-f]{4}\\\",\\\"dev_re\\\":\\\"^Gate-Dev: GATE-PASS dev .+\\\",\\\"uat_re\\\":\\\"^Gate-UAT: GATE-PASS uat .+\\\"}},\\\"repos\\\":{}}\" > $d/c.json && printf \"{\\\"deploy\\\":false}\" > $d/s.json && printf \"no gates\\n\" > $d/b.md && bash claude/workflow/gitops-ci/bin/gitops-gate-evidence.sh --repo jkkelley/homelab-gitops --select $d/s.json --config $d/c.json --body-file $d/b.md'",
      "exit": 0,
      "expect": "GATE-SKIP no-deploy-path"
    },
    {
      "index": 5,
      "command": "make -C claude/workflow image >/dev/null && podman run --rm --network=none --userns=keep-id -e HOME=/tmp -v \"$PWD:/work:Z\" -w /work localhost/dotfiles-workflow-test:1 bash -c 'd=$(mktemp -d) && printf \"{\\\"defaults\\\":{\\\"evidence\\\":{\\\"ticket_re\\\":\\\"WO-[0-9]{8}-[0-9a-f]{4}\\\",\\\"dev_re\\\":\\\"^Gate-Dev: GATE-PASS dev .+\\\",\\\"uat_re\\\":\\\"^Gate-UAT: GATE-PASS uat .+\\\"}},\\\"repos\\\":{}}\" > $d/c.json && printf \"{\\\"deploy\\\":true}\" > $d/s.json && jq -n --arg b \"$(printf \"WO-20261016-abcd\\nGate-Dev: GATE-PASS dev x\\nGate-UAT: GATE-PASS uat y\")\" \"{pull_request:{body:\\$b}}\" > $d/e.json && GITHUB_EVENT_PATH=$d/e.json bash claude/workflow/gitops-ci/bin/gitops-gate-evidence.sh --repo jkkelley/homelab-gitops --select $d/s.json --config $d/c.json'",
      "exit": 0,
      "expect": "GATE-OK WO-20261016-abcd dev uat"
    },
    {
      "index": 6,
      "command": "make -C claude/workflow image >/dev/null && podman run --rm --network=none --userns=keep-id -e HOME=/tmp -v \"$PWD:/work:Z\" -w /work localhost/dotfiles-workflow-test:1 bash -c 'd=$(mktemp -d) && printf \"{\\\"defaults\\\":{\\\"evidence\\\":{\\\"ticket_re\\\":\\\"WO-[0-9]{8}-[0-9a-f]{4}\\\",\\\"dev_re\\\":\\\"^Gate-Dev: GATE-PASS dev .+\\\",\\\"uat_re\\\":\\\"^Gate-UAT: GATE-PASS uat .+\\\"}},\\\"repos\\\":{}}\" > $d/c.json && printf \"{\\\"deploy\\\":true}\" > $d/s.json && env -u GITHUB_EVENT_PATH bash claude/workflow/gitops-ci/bin/gitops-gate-evidence.sh --repo jkkelley/homelab-gitops --select $d/s.json --config $d/c.json'",
      "exit": 0,
      "expect": "GATE-SKIP not-a-pr"
    },
    {
      "index": 7,
      "command": "make -C claude/workflow image >/dev/null && podman run --rm --network=none --userns=keep-id -e HOME=/tmp -v \"$PWD:/work:Z\" -w /work localhost/dotfiles-workflow-test:1 bash -c 'shellcheck -x claude/workflow/gitops-ci/bin/gitops-gate-evidence.sh'",
      "exit": 0,
      "expect": null
    },
    {
      "index": 8,
      "command": "git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/workflow/gitops-ci/bin/gitops-gate-evidence\\.sh)$'",
      "exit": 1,
      "expect": null
    }
  ],
  "provides": [
    "claude/workflow/gitops-ci/bin/gitops-gate-evidence.sh"
  ],
  "labels": [
    "line:inbox-triage"
  ]
}
---

# WO-20261016-3201 - gitops-gate-evidence.sh: a PR touching a deploy path is held until its body names its ticket and carries Gate-Dev and Gate-UAT GATE-PASS lines

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

A merge to a GitOps repo is a deploy: Argo CD applies main. merge-on-green merges any green PR, so a change that never passed its dev and UAT gates (Design principles 101 item 34) would deploy straight to stable.

## Owner words

> ORD-1128 K1 gitops CI tooling: tooling ticket first (rule 30): homelab-gitops CI, diff-selected and fast: yamllint and kubeconform on changed manifests, helm template plus kubeconform for changed charts, kustomize build for changed overlays, tracked-ignored-check, md-contents; plus the merge-on-green Action ported (one config entry if the template allows). A gitops merge is a deploy, so merge-on-green there also requires the PR dev and UAT gate evidence named in its ticket (rule 34). (orchestrator brief BR-20261016-infra-design19)

> Ensure that your testing is dev uat stable. (Design principles 101 item 34)

> reproduce errors or problems only with supporting evidence otherwise mute (Design principles 101 item 7)

## Context

Epic WO-20261016-770f holds the design. The gate runs as a CI job (make deploy-gate in the GitOps repo), so a missing line makes a check fail and merge-on-green already holds a head with a failed check; merge-on-green.yml is not touched (WO-20261016-39da and WO-20261016-ac25 own it). The GATE-PASS tokens are the ones homelab-gitops apps/line-ops gate scripts print (docs/line-ops/README.md: GATE-PASS dev deadman T0-T6). Config keys evidence.ticket_re, evidence.dev_re and evidence.uat_re come from claude/workflow/gitops-ci/config/gitops-ci.json (WO-20261016-b7ee); this ticket does not wait for it: its checks pass a fixture --config.

New file claude/workflow/gitops-ci/bin/gitops-gate-evidence.sh, mode 755, bash, set -euo pipefail, rolodex header block (writes-to: nothing, cleanup: none) as in claude/workflow/pr-flow/bin/pr-flow-config.sh. Usage: gitops-gate-evidence.sh --repo OWNER/NAME --select FILE [--body-file FILE] [--config FILE]; -h/--help prints usage containing gitops-gate-evidence.sh, exit 0; bad argument exit 2. Config: --config, else GITOPS_CI_CONFIG, else $HERE/../config/gitops-ci.json, resolved jq --arg r SLUG ".defaults * (.repos[\$r] // {})". Order: 1) if jq -r .deploy of the selection is not true, print "GATE-SKIP no-deploy-path", exit 0. 2) Body: --body-file content if given; else if GITHUB_EVENT_PATH is set and jq -e .pull_request of it succeeds, jq -r ".pull_request.body // \"\""; else print "GATE-SKIP not-a-pr", exit 0. 3) Strip every \r. 4) ticket: grep -oE ticket_re, first match T, else missing; dev: grep -qE dev_re; uat: grep -qE uat_re (per line, so ^ anchors at a line start). 5) Print one "GATE-MISSING ticket|dev|uat" line per missing item in that order; any missing: also print "GATE-HOLD add the ticket id and the Gate-Dev: and Gate-UAT: lines to the PR body, then push a commit (CI reads the body at the event)" and exit 1. 6) All present: print "GATE-OK T dev uat", exit 0.

GOOD: a PR body with "Ticket: WO-20261016-1234", "Gate-Dev: GATE-PASS dev deadman T0-T6 ~/.local/state/zenith/log/2026/10/<file>" and "Gate-UAT: GATE-PASS uat deadman U1-U3 <artifact path>" passes. NEVER: a deploy PR merged because its CI was green while no dev or UAT gate ran.

## Scope

**In**

- touches: claude/workflow/gitops-ci/bin/gitops-gate-evidence.sh (new)
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: branch from origin/main in your own git worktree (fallback: treehouse fails, use git worktree add), never the ~/dotfiles primary clone
- step: write the script exactly as in Context, chmod 755, then run checks 1-8 with bash claude/skills/work-order/scripts/work-order.sh check --id THIS-TICKET-ID
- step: commit 'feat(workflow): gitops-gate-evidence.sh holds a deploy PR without dev and UAT evidence' with the ticket id; no Bump trailer; push, open the PR, leave
- tool: make:claude/workflow/Makefile:image - on main; fallback: image build fails: retry 3 times, then stop with ENV-MISSING and the podman output
- tool: cmd:git, cmd:jq, cmd:make, cmd:podman, cmd:gh - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- changing claude/workflow/pr-flow/templates/merge-on-green.yml or ci.yml: the gate is a CI job
- reading the artifact store from CI: the PR body carries the evidence lines and their pointers
- any file not named under In: stop with DESIGN-GAP and hand it back to the design seat (item 30)
- work-orders/INDEX.md and epic READMEs by hand or by git add; waiting on CI or merging: push, open the PR, write the result, leave
- a Bump trailer: no skill under claude/skills changes

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* the usage prints
  - check: `make -C claude/workflow image >/dev/null && podman run --rm --network=none --userns=keep-id -e HOME=/tmp -v "$PWD:/work:Z" -w /work localhost/dotfiles-workflow-test:1 bash -c 'bash claude/workflow/gitops-ci/bin/gitops-gate-evidence.sh --help'` exit 0 expect /gitops-gate-evidence\.sh/
- [ ] `AC-H2` *(human)* a deploy PR with ticket, dev and UAT lines passes, CRLF body
  - check: `make -C claude/workflow image >/dev/null && podman run --rm --network=none --userns=keep-id -e HOME=/tmp -v "$PWD:/work:Z" -w /work localhost/dotfiles-workflow-test:1 bash -c 'd=$(mktemp -d) && printf "{\"defaults\":{\"evidence\":{\"ticket_re\":\"WO-[0-9]{8}-[0-9a-f]{4}\",\"dev_re\":\"^Gate-Dev: GATE-PASS dev .+\",\"uat_re\":\"^Gate-UAT: GATE-PASS uat .+\"}},\"repos\":{}}" > $d/c.json && printf "{\"deploy\":true}" > $d/s.json && printf "Ticket WO-20261016-abcd\r\nGate-Dev: GATE-PASS dev line-ops T0-T6\r\nGate-UAT: GATE-PASS uat line-ops U1\r\n" > $d/b.md && bash claude/workflow/gitops-ci/bin/gitops-gate-evidence.sh --repo jkkelley/homelab-gitops --select $d/s.json --config $d/c.json --body-file $d/b.md'` exit 0 expect /GATE-OK WO-20261016-abcd dev uat/
- [ ] `AC-H3` *(human)* a deploy PR without UAT evidence is held
  - check: `make -C claude/workflow image >/dev/null && podman run --rm --network=none --userns=keep-id -e HOME=/tmp -v "$PWD:/work:Z" -w /work localhost/dotfiles-workflow-test:1 bash -c 'd=$(mktemp -d) && printf "{\"defaults\":{\"evidence\":{\"ticket_re\":\"WO-[0-9]{8}-[0-9a-f]{4}\",\"dev_re\":\"^Gate-Dev: GATE-PASS dev .+\",\"uat_re\":\"^Gate-UAT: GATE-PASS uat .+\"}},\"repos\":{}}" > $d/c.json && printf "{\"deploy\":true}" > $d/s.json && printf "Ticket WO-20261016-abcd\nGate-Dev: GATE-PASS dev line-ops T0-T6\n" > $d/b.md && bash claude/workflow/gitops-ci/bin/gitops-gate-evidence.sh --repo jkkelley/homelab-gitops --select $d/s.json --config $d/c.json --body-file $d/b.md'` exit 1 expect /GATE-MISSING uat/
- [ ] `AC-H4` *(human)* a PR touching no deploy path is skipped
  - check: `make -C claude/workflow image >/dev/null && podman run --rm --network=none --userns=keep-id -e HOME=/tmp -v "$PWD:/work:Z" -w /work localhost/dotfiles-workflow-test:1 bash -c 'd=$(mktemp -d) && printf "{\"defaults\":{\"evidence\":{\"ticket_re\":\"WO-[0-9]{8}-[0-9a-f]{4}\",\"dev_re\":\"^Gate-Dev: GATE-PASS dev .+\",\"uat_re\":\"^Gate-UAT: GATE-PASS uat .+\"}},\"repos\":{}}" > $d/c.json && printf "{\"deploy\":false}" > $d/s.json && printf "no gates\n" > $d/b.md && bash claude/workflow/gitops-ci/bin/gitops-gate-evidence.sh --repo jkkelley/homelab-gitops --select $d/s.json --config $d/c.json --body-file $d/b.md'` exit 0 expect /GATE-SKIP no-deploy-path/
- [ ] `AC-H5` *(human)* the body is read from GITHUB_EVENT_PATH
  - check: `make -C claude/workflow image >/dev/null && podman run --rm --network=none --userns=keep-id -e HOME=/tmp -v "$PWD:/work:Z" -w /work localhost/dotfiles-workflow-test:1 bash -c 'd=$(mktemp -d) && printf "{\"defaults\":{\"evidence\":{\"ticket_re\":\"WO-[0-9]{8}-[0-9a-f]{4}\",\"dev_re\":\"^Gate-Dev: GATE-PASS dev .+\",\"uat_re\":\"^Gate-UAT: GATE-PASS uat .+\"}},\"repos\":{}}" > $d/c.json && printf "{\"deploy\":true}" > $d/s.json && jq -n --arg b "$(printf "WO-20261016-abcd\nGate-Dev: GATE-PASS dev x\nGate-UAT: GATE-PASS uat y")" "{pull_request:{body:\$b}}" > $d/e.json && GITHUB_EVENT_PATH=$d/e.json bash claude/workflow/gitops-ci/bin/gitops-gate-evidence.sh --repo jkkelley/homelab-gitops --select $d/s.json --config $d/c.json'` exit 0 expect /GATE-OK WO-20261016-abcd dev uat/
- [ ] `AC-H6` *(human)* outside a pull request event it skips
  - check: `make -C claude/workflow image >/dev/null && podman run --rm --network=none --userns=keep-id -e HOME=/tmp -v "$PWD:/work:Z" -w /work localhost/dotfiles-workflow-test:1 bash -c 'd=$(mktemp -d) && printf "{\"defaults\":{\"evidence\":{\"ticket_re\":\"WO-[0-9]{8}-[0-9a-f]{4}\",\"dev_re\":\"^Gate-Dev: GATE-PASS dev .+\",\"uat_re\":\"^Gate-UAT: GATE-PASS uat .+\"}},\"repos\":{}}" > $d/c.json && printf "{\"deploy\":true}" > $d/s.json && env -u GITHUB_EVENT_PATH bash claude/workflow/gitops-ci/bin/gitops-gate-evidence.sh --repo jkkelley/homelab-gitops --select $d/s.json --config $d/c.json'` exit 0 expect /GATE-SKIP not-a-pr/
- [ ] `AC-H7` *(human)* shellcheck passes
  - check: `make -C claude/workflow image >/dev/null && podman run --rm --network=none --userns=keep-id -e HOME=/tmp -v "$PWD:/work:Z" -w /work localhost/dotfiles-workflow-test:1 bash -c 'shellcheck -x claude/workflow/gitops-ci/bin/gitops-gate-evidence.sh'` exit 0
- [ ] `AC-H8` *(human)* the diff holds only the In files
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/workflow/gitops-ci/bin/gitops-gate-evidence\.sh)$'` exit 1

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

claude/workflow/gitops-ci/bin/gitops-gate-evidence.sh, the dev and UAT evidence gate

**Cases**

- `TP-1`
  - intent: a deploy PR with its ticket and both gate lines passes (rule 34), CRLF bodies included
  - command: `make -C claude/workflow image >/dev/null && podman run --rm --network=none --userns=keep-id -e HOME=/tmp -v "$PWD:/work:Z" -w /work localhost/dotfiles-workflow-test:1 bash -c 'd=$(mktemp -d) && printf "{\"defaults\":{\"evidence\":{\"ticket_re\":\"WO-[0-9]{8}-[0-9a-f]{4}\",\"dev_re\":\"^Gate-Dev: GATE-PASS dev .+\",\"uat_re\":\"^Gate-UAT: GATE-PASS uat .+\"}},\"repos\":{}}" > $d/c.json && printf "{\"deploy\":true}" > $d/s.json && printf "Ticket WO-20261016-abcd\r\nGate-Dev: GATE-PASS dev line-ops T0-T6\r\nGate-UAT: GATE-PASS uat line-ops U1\r\n" > $d/b.md && bash claude/workflow/gitops-ci/bin/gitops-gate-evidence.sh --repo jkkelley/homelab-gitops --select $d/s.json --config $d/c.json --body-file $d/b.md'`
  - expected: exit 0 and GATE-OK WO-20261016-abcd dev uat
- `TP-2`
  - intent: a deploy PR missing UAT evidence is held, since a gitops merge is a deploy
  - command: `make -C claude/workflow image >/dev/null && podman run --rm --network=none --userns=keep-id -e HOME=/tmp -v "$PWD:/work:Z" -w /work localhost/dotfiles-workflow-test:1 bash -c 'd=$(mktemp -d) && printf "{\"defaults\":{\"evidence\":{\"ticket_re\":\"WO-[0-9]{8}-[0-9a-f]{4}\",\"dev_re\":\"^Gate-Dev: GATE-PASS dev .+\",\"uat_re\":\"^Gate-UAT: GATE-PASS uat .+\"}},\"repos\":{}}" > $d/c.json && printf "{\"deploy\":true}" > $d/s.json && printf "Ticket WO-20261016-abcd\nGate-Dev: GATE-PASS dev line-ops T0-T6\n" > $d/b.md && bash claude/workflow/gitops-ci/bin/gitops-gate-evidence.sh --repo jkkelley/homelab-gitops --select $d/s.json --config $d/c.json --body-file $d/b.md'`
  - expected: exit 1 and GATE-MISSING uat
- `TP-3`
  - intent: a PR that touches no deploy path is never held
  - command: `make -C claude/workflow image >/dev/null && podman run --rm --network=none --userns=keep-id -e HOME=/tmp -v "$PWD:/work:Z" -w /work localhost/dotfiles-workflow-test:1 bash -c 'd=$(mktemp -d) && printf "{\"defaults\":{\"evidence\":{\"ticket_re\":\"WO-[0-9]{8}-[0-9a-f]{4}\",\"dev_re\":\"^Gate-Dev: GATE-PASS dev .+\",\"uat_re\":\"^Gate-UAT: GATE-PASS uat .+\"}},\"repos\":{}}" > $d/c.json && printf "{\"deploy\":false}" > $d/s.json && printf "no gates\n" > $d/b.md && bash claude/workflow/gitops-ci/bin/gitops-gate-evidence.sh --repo jkkelley/homelab-gitops --select $d/s.json --config $d/c.json --body-file $d/b.md'`
  - expected: exit 0 and GATE-SKIP no-deploy-path
- `TP-4`
  - intent: in CI the body is read from GITHUB_EVENT_PATH
  - command: `make -C claude/workflow image >/dev/null && podman run --rm --network=none --userns=keep-id -e HOME=/tmp -v "$PWD:/work:Z" -w /work localhost/dotfiles-workflow-test:1 bash -c 'd=$(mktemp -d) && printf "{\"defaults\":{\"evidence\":{\"ticket_re\":\"WO-[0-9]{8}-[0-9a-f]{4}\",\"dev_re\":\"^Gate-Dev: GATE-PASS dev .+\",\"uat_re\":\"^Gate-UAT: GATE-PASS uat .+\"}},\"repos\":{}}" > $d/c.json && printf "{\"deploy\":true}" > $d/s.json && jq -n --arg b "$(printf "WO-20261016-abcd\nGate-Dev: GATE-PASS dev x\nGate-UAT: GATE-PASS uat y")" "{pull_request:{body:\$b}}" > $d/e.json && GITHUB_EVENT_PATH=$d/e.json bash claude/workflow/gitops-ci/bin/gitops-gate-evidence.sh --repo jkkelley/homelab-gitops --select $d/s.json --config $d/c.json'`
  - expected: exit 0 and GATE-OK

**Isolation**

- runtime: podman
- image: localhost/dotfiles-workflow-test:1
- build: make -C claude/workflow image
- containerfile: claude/workflow/tests/container/Containerfile

**Out of scope - CI covers**

- lint and the full suite: CI runs them (Design principles 101 item 6)

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
