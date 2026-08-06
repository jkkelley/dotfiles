---
name: work-order
description: Deterministic ticketing for agent handoff. Creates and drives work-orders through a validated lifecycle, binding acceptance criteria to Figma wireframe evidence when it exists. Use when the user asks for a ticket, a work-order, "cut me a ticket", "write this up as work", when handing a task to another agent, or says "work-order with a side of figma" (run figma-wireframe first, then feed its output in). Not for prioritising a backlog - that is project-scaffold's BACKLOG.md.
---

# Work Order

Tickets an agent can act on without asking a follow-up question. The determinism
comes from one rule: **the script writes the ticket, never the model.**

An agent hand-writing ticket markdown is the failure this skill removes. Every
field, every transition, every archive move goes through `scripts/work-order.sh`.

## Requirements

- `bash` 4+, `jq`, `git`. `gh` for `submit` and `close`.
- `lavish-axi` to approve a ticket. Without it, `approve` refuses unless you pass
  `--no-lavish --reason "..."`, which records the exception in the ticket.

Why jq when `lib/common.sh` deliberately avoids it: common.sh only ever _emits_
JSON, which hand-rolled bash does safely. work-order _reads_ nested JSON out of
`build-plan.json`, and hand-rolled JSON parsing in bash is exactly the kind of
thing that stops being deterministic. jq reads; `ps_json_string` writes.

## Which document wins

| Situation          | Authority                                                                                                                                                            |
| ------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Wireframes present | `build-plan.json` leads. Screens, states, `done_when` and `non_goals` come from it. The ticket is guidance layered on top and may never contradict the frozen block. |
| No wireframes      | The ticket leads. It is the sole source of truth, `evidence.source` is `human`, every criterion is `(human)`.                                                        |

A conflict between the two is a drift error, not something to merge by hand.

## Lifecycle

The status set is closed. Every transition is validated and an illegal one is
refused by name. Full table, including what each transition writes and what makes
it refuse, is in `references/lifecycle.md`.

| #   | Status        | Set by    | Gate                                 | Legal next              |
| --- | ------------- | --------- | ------------------------------------ | ----------------------- |
| 1   | `draft`       | `new`     | Rendered in Lavish for review        | `ready`                 |
| 2   | `ready`       | `approve` | Lavish approval. Lavish is done here | `in-progress`, `stale`  |
| 3   | `in-progress` | `start`   | Creates and stamps the branch        | `in-review`             |
| 4   | `in-review`   | `submit`  | Human review gate on the PR          | `done`                  |
| 5   | `done`        | `done`    | Last feature commit, at compaction   | _(archived by `close`)_ |
| —   | `stale`       | `verify`  | Frozen block drifted                 | `ready` via `resync`    |

`done` is written on the feature branch **before** the PR lands, alongside the
`context-compaction` update to `CONTEXT_STATE.md`. That is a deliberate choice: it
means a rejected PR leaves a ticket claiming done, which is what `reopen` exists
to correct.

## Usage

```bash
WO=.claude/skills/work-order/scripts/work-order.sh

# generic path - no design involved
bash $WO new --title "Retry failed webhook deliveries" --type bug \
  --problem "Deliveries that 500 are dropped silently" \
  --in "exponential backoff" --out "changing the payload schema" \
  --ac "a 500 is retried three times then dead-lettered" \
  --test-plan "podman run --rm -v \$PWD:/w -w /w node:22 npm test -- webhooks"

# figma path - "a work-order with a side of figma"
bash $WO new --title "Empty cart state" --type feature --problem "..." \
  --out "payment errors" --from-figma . --frames 'wf/checkout-cart/*'

bash $WO approve --id WO-20260805-3f2a     # after Lavish review
bash $WO start   --id WO-20260805-3f2a     # creates feat/<slug>
bash $WO submit  --id WO-20260805-3f2a --pr 42
bash $WO done    --id WO-20260805-3f2a     # last feature commit
bash $WO close   --id WO-20260805-3f2a --dry-run
bash $WO close   --id WO-20260805-3f2a     # post-merge only
```

Every subcommand takes `--project DIR`, `--json`, `--help`. Exit codes match
`backlog.sh`: `0` ok, `2` usage, `3` validation or illegal transition, `4`
io/missing dependency, `5` lock timeout, `6` id not found.

### Working with figma-wireframe

Run figma-wireframe to completion first, then point `--from-figma` at the
directory holding `wireframe-brief.json` and `build-plan.json`. work-order
**snapshots both files** into `work-orders/evidence/<ID>/`, because
figma-wireframe writes fixed filenames into the working directory - wireframing a
second feature would otherwise destroy the first ticket's evidence.

`build-plan.json` carries no Figma node IDs; those only exist after the build
step. Frames are therefore recorded by their deterministic `id` and `name`, which
an agent resolves with `get_metadata`.

Use `--frames` to cut one ticket per screen off a multi-screen brief.

## The close-out

`close` is the only command that touches git history, and the only parameter it
accepts is `--id`. Everything else it discovers:

| Fact       | Source                            |
| ---------- | --------------------------------- |
| branch     | recorded in the ticket at `start` |
| PR number  | recorded at `submit`              |
| merged y/n | `gh pr view --json state`         |
| merge SHA  | `gh pr view --json mergeCommit`   |

**It never trusts a claim that a PR merged.** It asks `gh`, refuses anything but
`MERGED`, and refuses a `MERGED` with no merge commit. After checking out `main`
it re-reads the ticket, because the checkout swaps the file for main's copy.

Three phases, each completing before the next: cleanup → close-out PR → cleanup.
`--dry-run` prints the whole plan and every assertion result and executes nothing.

## Testing

`bash testing/run-tests.sh`. Podman, `--network=none`, skill mounted read-only,
per root CLAUDE.md Rule 14. The suite builds its own image because no stock slim
image carries both `jq` and `git`; the base is pinned by digest per Rule 15.

`gh` is never installed - each case stubs it, because the point of the close tests
is controlling what `gh` reports. Cases 070 and 090 run against a real bare
repository, so branch deletion and archiving are genuinely exercised.

## Bundled resources

- `references/lifecycle.md` — the full status table: setter, gate, legal successors, what it writes, what makes it refuse.
- `references/ticket.tmpl` — the body skeleton. `new` fills it; nobody edits a ticket by hand.
- `scripts/work-order.sh` — every subcommand.
- `scripts/lib/wo.sh` — identity, frontmatter, wireframe binding.
- `scripts/lib/common.sh` — vendored from project-scaffold so this skill is independently consumable.
- `settings.json.tmpl`, `settings.local.json.tmpl` — allowlist the script, and deliberately do **not** allowlist raw `git branch -D` / `git push --delete`, so hand-rolled cleanup is not an available path.
