---
{
  "id": "WO-20261016-9ad9",
  "slug": "line-ops-pr-sweep-sh-the-cronjob-entry-checks-se",
  "title": "line-ops pr-sweep.sh: the CronJob entry checks secrets, syncs the dotfiles tools and the swept clones on the work volume, then runs one pr-flow sweep against the cluster bus",
  "type": "feature",
  "status": "in-review",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T10:54:05+00:00",
  "parent": "WO-20261016-ab87",
  "branch": "feat/9ad9-line-ops-pr-sweep-sh-the-cronjob-entry-checks-se",
  "pr": 106,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "ops-design1 cut for ORD-1042 G1 cluster-ops; design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": [
    "WO-20261016-03ef"
  ],
  "ac_checks": [
    {
      "index": 1,
      "command": "bash apps/line-ops/scripts/test-pr-sweep.sh",
      "exit": 0,
      "expect": "ok pr-sweep: 7 cases"
    },
    {
      "index": 2,
      "command": "shellcheck -S warning apps/line-ops/base/pr-sweep.sh apps/line-ops/scripts/test-pr-sweep.sh",
      "exit": 0,
      "expect": null
    },
    {
      "index": 3,
      "command": "grep -nE 'echo.*(GH_TOKEN|NATS_TOKEN|NATS_URL)\\}?\"?$|printf.*\\$\\{?(GH_TOKEN|NATS_TOKEN)' apps/line-ops/base/pr-sweep.sh",
      "exit": 1,
      "expect": null
    },
    {
      "index": 4,
      "command": "git diff --name-only origin/main...HEAD | grep -vE '^(apps/line-ops/(base/pr-sweep\\.sh|scripts/test-pr-sweep\\.sh))$'",
      "exit": 1,
      "expect": null
    }
  ],
  "provides": [
    "path:apps/line-ops/base/pr-sweep.sh",
    "path:apps/line-ops/scripts/test-pr-sweep.sh"
  ],
  "labels": [
    "line:inbox-triage"
  ],
  "repo": "jkkelley/homelab-gitops"
}
---

# WO-20261016-9ad9 - line-ops pr-sweep.sh: the CronJob entry checks secrets, syncs the dotfiles tools and the swept clones on the work volume, then runs one pr-flow sweep against the cluster bus

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

A CronJob pod starts empty: it has no dotfiles checkout, no clones of the swept repositories, a pr-flow config whose clone paths name the owner's WSL home, and a bus URL of 127.0.0.1. pr-flow-consume.sh skips regen and autofix when a clone is missing and posts through bus.sh, which runs podman unless BUS_NATS is set. One entry script must close that gap before the sweep runs, without changing dotfiles (three open dotfiles tickets, WO-20261016-fb99, WO-20261016-c6a5 and WO-20261016-73f2, touch pr-flow-consume.sh and pr-flow.mk).

## Owner words

> ORD-1042 G1 (brief BR-20261016-ops-design1): L1 cluster-ops deploy: homelab-gitops app for the bus, merge-on-green sweeps and stuck-watch as CronJobs (rule 39); secrets via external-secrets and Vault, never read a credential

> i don't like agents doing shit when i have a k8s cluster too, automate processes right away (Design principles 101 item 39)

> Have fallbacks too (item 28); Ensure that your testing is dev uat stable. (item 34); And don't ever bog the user down with notifications when testing. (item 35)

## Context

Reuse: dotfiles claude/workflow/pr-flow/bin/pr-flow-consume.sh (verbs sweep, regen-index, rerun-stale-red, autofix; env REPO, PR_FLOW_CONFIG, PR_FLOW_STATE, GH), pr-flow-config.sh (--list prints the repos keys of PR_FLOW_CONFIG), claude/workflow/bin/bus.sh (NATS_URL, and BUS_NATS=nats runs the nats CLI directly instead of podman). Pattern: base/deadman.sh and base/bus-init.sh are shipped by configMapGenerator.

New file apps/line-ops/base/pr-sweep.sh (bash, set -uo pipefail, header comment with name, purpose, inputs, outputs, exit codes and a breadcrumb naming this ticket, rule 39 and the rejected alternative: a cluster copy of pr-flow.json, which drifts from dotfiles). Inputs, all env, defaults in brackets: WORK [/work], DOTFILES_URL [https://github.com/jkkelley/dotfiles.git], DOTFILES_REF [main], CLONE_BASE [https://github.com], NATS_HOST [nats.line-ops.svc:4222], NATS_TOKEN, GH_TOKEN, GIT_NAME [line-ops pr-sweep], GIT_EMAIL [pr-sweep@line-ops.invalid], REPO [empty = every configured repo], PR_SWEEP_VERB [sweep], GH [gh].

Behaviour, fixed, in order: (1) GH_TOKEN empty: stdout 'SECRET-MISSING GH_TOKEN', exit 2; NATS_TOKEN empty: 'SECRET-MISSING NATS_TOKEN', exit 2; never echo either value. (2) export HOME=$WORK/home, mkdir -p it; "$GH" auth setup-git; git config --global user.name "$GIT_NAME" and user.email "$GIT_EMAIL". (3) tools checkout D=$WORK/dotfiles: if D/.git exists, git -C D fetch -q --depth 1 origin "$DOTFILES_REF" then git -C D checkout -q --force FETCH_HEAD; else git clone -q --depth 1 --branch "$DOTFILES_REF" "$DOTFILES_URL" D. Each git network call runs under timeout 120 and is retried up to 3 times; after the third failure stdout 'CLONE-FAIL dotfiles', exit 3. (4) render PR_FLOW_CONFIG=$WORK/pr-flow.json with jq --arg root "$WORK/clones" '.repos |= with_entries(.value.clone = ($root + "/" + (.key | split("/")[1])))' D/claude/workflow/pr-flow/config/pr-flow.json, written to a temp file then mv (atomic); export PR_FLOW_CONFIG. (5) for each slug in REPO, or else in $(D/claude/workflow/pr-flow/bin/pr-flow-config.sh --list): C=$WORK/clones/${slug#*/}; if C/.git exists git -C C fetch -q --prune origin, else git clone -q --filter=blob:none "$CLONE_BASE/$slug.git" C; same timeout and 3 tries; on the third failure stdout 'CLONE-FAIL <slug>', exit 3. stdout 'synced <slug>' per repo. (6) export PR_FLOW_STATE=$WORK/state BUS_NATS=nats NATS_URL="nats://${NATS_TOKEN}@${NATS_HOST}" (the token rides the URL inside the pod only; the script never prints NATS_URL), then exec D/claude/workflow/pr-flow/bin/pr-flow-consume.sh "$PR_SWEEP_VERB", so the sweep's exit code is the pod's. Idempotent: a second run fetches instead of cloning and lands in the same state.

New file apps/line-ops/scripts/test-pr-sweep.sh (dev gate, item 34): runs pr-sweep.sh in podman image docker.io/library/debian@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251 (debian:bookworm-slim; apt-get install -y -qq git jq ca-certificates at the start of the container run), --userns=keep-id is not needed, the repo mounted read-only with :Z. Fakes only, no network beyond apt: fixture bare repos built in mktemp: a 'dotfiles' repo with claude/workflow/pr-flow/config/pr-flow.json ({"defaults":{},"repos":{"o/a":{"clone":"~/a"},"o/b":{"clone":"~/b"}}}), bin/pr-flow-config.sh (the --list jq one-liner) and a fake bin/pr-flow-consume.sh that writes its argv and env NATS_URL, BUS_NATS, PR_FLOW_STATE, PR_FLOW_CONFIG to $WORK/consume.log; bare repos o/a.git and o/b.git under a CLONE_BASE dir; a stub gh on PATH that logs its args and exits 0. DOTFILES_URL=file://<fixture>, CLONE_BASE=file://<dir>, NATS_HOST=fake:4222, NATS_TOKEN=tok, GH_TOKEN=x. Prints 'ok (N) <case>' per case and ends with exactly 'ok pr-sweep: 7 cases'; exit 1 on any failure. Cases: 1 GH_TOKEN empty -> exit 2, stdout SECRET-MISSING GH_TOKEN, nothing cloned; 2 NATS_TOKEN empty -> exit 2 SECRET-MISSING NATS_TOKEN; 3 first run -> exit 0, synced o/a and o/b, $WORK/pr-flow.json clones are $WORK/clones/a and $WORK/clones/b, consume.log shows argv sweep, NATS_URL nats://tok@fake:4222, BUS_NATS nats, PR_FLOW_STATE $WORK/state; 4 second run -> exit 0, same consume.log content, clones fetched not recloned (inode of $WORK/clones/a/.git unchanged); 5 CLONE_BASE missing o/b -> exit 3, stdout CLONE-FAIL o/b; 6 REPO=o/a on a fresh WORK -> only clones/a exists; 7 PR_SWEEP_VERB=regen-index -> consume.log argv regen-index. Retries in case 5 use PR_SWEEP_RETRY_SLEEP=0 (an env the script honours, default 5 seconds between tries).

## Scope

**In**

- touches: apps/line-ops/base/pr-sweep.sh (new, behaviour in Context)
- touches: apps/line-ops/scripts/test-pr-sweep.sh (new, the 7 cases in Context)
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path in dotfiles; dotfiles work-orders/INDEX.md and the epic README.md are ignored generated views
- step: clone or worktree jkkelley/homelab-gitops from origin/main into your own worktree under ~/.cache (git worktree add from ~/projects/homelab-gitops; fallback: git clone), branch feat/<slug>; every path and AC command below runs from that worktree's root
- step: write the two files exactly as in Context
- step: run bash apps/line-ops/scripts/test-pr-sweep.sh and shellcheck through the AC checks only (the Make target is the gate ticket's)
- step: commit 'feat(line-ops): pr-sweep.sh, the cluster entry for the pr-flow sweep' with the ticket id, push, open the PR on jkkelley/homelab-gitops, leave
- tool: image docker.io/library/debian@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251 - fallback: pull fails: retry 3 times, then stop with ENV-MISSING podman
- tool: cmd:shellcheck - fallback: missing on the host: run it as podman run --rm -v "$PWD:/w:Z" -w /w docker.io/koalaman/shellcheck:v0.10.0 (pin by digest at use, Rule 15) or stop with ENV-MISSING shellcheck
- tool: cmd:podman - fallback: missing or no network for pulls: retry 3 times, then stop with ENV-MISSING podman
- tool: cmd:git, cmd:gh, cmd:jq, cmd:make - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- apps/line-ops/Makefile and the UAT gate: the gate ticket
- the CronJob manifest and kustomization: the CronJob ticket
- any dotfiles file
- any file not named under In: stop with DESIGN-GAP and hand it back to the design seat (item 30)
- waiting on CI or merging: push, open the PR, write the result, leave
- reading, printing or writing any credential value: secrets reach pods only through external-secrets from Vault; the owner seeds Vault
- a Bump trailer: no skill under claude/skills changes

## Degrees of freedom

- [free] [fixed] None declared: implement exactly as specified; stop with DESIGN-GAP before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* the 7 pr-sweep cases pass in podman against fakes
  - observed `2026-10-16` ok pr-sweep: 7 cases, exit 0, homelab-gitops PR 106
  - check: `bash apps/line-ops/scripts/test-pr-sweep.sh` exit 0 expect /ok pr-sweep: 7 cases/
- [x] `AC-H2` *(human)* both scripts pass shellcheck at warning
  - observed `2026-10-16` shellcheck -S warning exit 0, no output
  - check: `shellcheck -S warning apps/line-ops/base/pr-sweep.sh apps/line-ops/scripts/test-pr-sweep.sh` exit 0
- [x] `AC-H3` *(human)* the script never prints a token
  - observed `2026-10-16` grep exit 1, no match
  - check: `grep -nE 'echo.*(GH_TOKEN|NATS_TOKEN|NATS_URL)\}?"?$|printf.*\$\{?(GH_TOKEN|NATS_TOKEN)' apps/line-ops/base/pr-sweep.sh` exit 1
- [x] `AC-H4` *(human)* the diff holds only In files
  - observed `2026-10-16` diff vs origin/main on PR 106 holds only the two In files, grep exit 1
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(apps/line-ops/(base/pr-sweep\.sh|scripts/test-pr-sweep\.sh))$'` exit 1

## Test plan

```sh
{"scope":"pr-sweep.sh against fixture repos, a stub gh and a fake consume script","cases":[{"id":"TP-1","intent":"the pod must refuse without secrets, sync idempotently, fail loud on a clone it cannot get, and hand the sweep the cluster bus and its state dir","command":"bash apps/line-ops/scripts/test-pr-sweep.sh","expected":"exit 0; 7 ok lines, last ok pr-sweep: 7 cases"},{"id":"TP-2","intent":"lint","command":"shellcheck -S warning apps/line-ops/base/pr-sweep.sh apps/line-ops/scripts/test-pr-sweep.sh","expected":"exit 0"}],"isolation":{"runtime":"podman","image":"docker.io/library/debian@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251"},"out_of_scope":["the real sweep against GitHub and the cluster bus: the UAT gate ticket"]}
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
