---
{
  "id": "WO-20261016-0a4c",
  "slug": "monitors-json-pr-flow-pane-watches-the-cluster-p",
  "title": "monitors.json pr-flow pane watches the cluster pr-sweep jobs instead of running the local sweep loop",
  "type": "chore",
  "status": "ready",
  "priority": "p2",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T10:55:58+00:00",
  "parent": "WO-20261016-ab87",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "ops-design1 cut for ORD-1042 G1 cluster-ops; design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-c315"
  ],
  "blocks": [],
  "ac_checks": [
    {
      "index": 1,
      "command": "jq -r '.monitors[] | select(.name==\"pr-flow\") | \"\\(.command)|\\(.down // \"none\")\"' claude/workflow/config/monitors.json",
      "exit": 0,
      "expect": "^kubectl -n line-ops get jobs -l app\\.kubernetes\\.io/name=pr-sweep --watch\\|none$"
    },
    {
      "index": 2,
      "command": "diff <(git show origin/main:claude/workflow/config/monitors.json | jq -S '[.monitors[] | select(.name != \"pr-flow\")]') <(jq -S '[.monitors[] | select(.name != \"pr-flow\")]' claude/workflow/config/monitors.json)",
      "exit": 0,
      "expect": null
    },
    {
      "index": 3,
      "command": "git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/workflow/config/monitors\\.json)$'",
      "exit": 1,
      "expect": null
    }
  ],
  "provides": [],
  "labels": [
    "line:inbox-triage"
  ]
}
---

# WO-20261016-0a4c - monitors.json pr-flow pane watches the cluster pr-sweep jobs instead of running the local sweep loop

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

Once CronJob pr-sweep runs on the stable line, the monitors.json entry pr-flow (command make -C ${repo} pr-flow-consume) would start a second sweep with its own ledger and double-post records. Rule 27 keeps a labeled pane for every monitor, so the pane stays and only its command changes.

## Owner words

> ORD-1042 G1 (brief BR-20261016-ops-design1): L1 cluster-ops deploy: homelab-gitops app for the bus, merge-on-green sweeps and stuck-watch as CronJobs (rule 39); secrets via external-secrets and Vault, never read a credential

> i don't like agents doing shit when i have a k8s cluster too, automate processes right away (Design principles 101 item 39)

> Have fallbacks too (item 28); Ensure that your testing is dev uat stable. (item 34); And don't ever bog the user down with notifications when testing. (item 35)

> that lives and dies in a monitoring tab too along with those scripts from makefiles (item 27)

## Context

claude/workflow/config/monitors.json entry name pr-flow (owner merge-port, slot 3.3): command becomes 'kubectl -n line-ops get jobs -l app.kubernetes.io/name=pr-sweep --watch', the 'down' key is removed (the watch ends with its pane), and the entry gains a '$comment' key: 'Rule 39 (owner 2026-10-16): the sweep runs as CronJob pr-sweep in homelab-gitops apps/line-ops; this pane only watches its jobs. Rollback: restore command make -C ${repo} pr-flow-consume and down make -C ${repo} pr-flow-consume-stop. Ticket: <this ticket id>.' JSON has no comments, so the $comment key is the breadcrumb. No other entry changes.

Order: WO-20261016-cc95 (pane-look monitor, in review) also touches monitors.json; rebase on origin/main after it merges, never edit its entries.

## Scope

**In**

- touches: claude/workflow/config/monitors.json (the pr-flow entry only)
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path in dotfiles; dotfiles work-orders/INDEX.md and the epic README.md are ignored generated views
- step: branch from origin/main in your own git worktree, never the ~/dotfiles primary clone
- step: precondition: kubectl -n line-ops get cronjob pr-sweep -o jsonpath='{.spec.suspend}' prints false; else stop with A2A-003 (the promotion has not synced)
- step: edit the entry exactly as in Context with jq into a temp file then mv, run the AC checks only
- step: commit 'chore(workflow): pr-flow monitor watches the cluster pr-sweep' with the ticket id; no Bump trailer; push, open the PR, leave
- tool: cmd:kubectl (cluster context of the owner's homelab) - fallback: cluster unreachable: retry 3 times 30 s apart, then stop with A2A-003 and the kubectl error; no local substitute
- tool: cmd:git, cmd:gh, cmd:jq, cmd:make - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- claude/workflow/pr-flow/* (open tickets WO-20261016-fb99, WO-20261016-c6a5 and WO-20261016-73f2 own pr-flow-consume.sh and pr-flow.mk)
- any other monitors.json entry
- any file not named under In: stop with DESIGN-GAP and hand it back to the design seat (item 30)
- waiting on CI or merging: push, open the PR, write the result, leave
- reading, printing or writing any credential value: secrets reach pods only through external-secrets from Vault; the owner seeds Vault
- a Bump trailer: no skill under claude/skills changes

## Degrees of freedom

- [free] [fixed] None declared: implement exactly as specified; stop with DESIGN-GAP before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* the pr-flow pane watches the cluster jobs and no longer starts the loop
  - check: `jq -r '.monitors[] | select(.name=="pr-flow") | "\(.command)|\(.down // "none")"' claude/workflow/config/monitors.json` exit 0 expect /^kubectl -n line-ops get jobs -l app\.kubernetes\.io/name=pr-sweep --watch\|none$/
- [ ] `AC-H2` *(human)* every other entry is unchanged
  - check: `diff <(git show origin/main:claude/workflow/config/monitors.json | jq -S '[.monitors[] | select(.name != "pr-flow")]') <(jq -S '[.monitors[] | select(.name != "pr-flow")]' claude/workflow/config/monitors.json)` exit 0
- [ ] `AC-H3` *(human)* the diff holds only In files
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/workflow/config/monitors\.json)$'` exit 1

## Test plan

```sh
{"scope":"monitors.json read with jq; no pane started","cases":[{"id":"TP-1","intent":"a second local sweep double-posts records; the pane must only watch","command":"AC-H1 and AC-H2","expected":"the watch command and none; empty diff"}],"isolation":{"runtime":"podman","image":"none: jq on a config file"},"out_of_scope":["bin/monitors.sh placing the pane: the next monitor tab start"]}
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
