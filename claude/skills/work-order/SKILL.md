---
name: work-order
description: Deterministic ticketing for agent handoff. Creates and drives work-orders through a validated lifecycle, organises them as epics with children and a dependency graph, records progress notes, and binds acceptance criteria to Figma wireframe evidence when it exists. Use when the user asks for a ticket, a work-order, an epic, "cut me a ticket", "write this up as work", "what should I work on next", when handing a task to another agent, when adding a note or a dependency to existing work, or says "work-order with a side of figma" (run figma-wireframe first, then feed its output in). Not for prioritising a backlog - that is project-scaffold's BACKLOG.md.
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

## How the directory is organised

One rule: **a child ticket lives in the directory named for its parent.**

```
work-orders/
├── INDEX.md                              generated router - read this first
├── WO-20260810-e21f-dev001-pipeline.md   an epic
├── WO-20260810-e21f/                      ...and its children, one level down
│   ├── WO-20260810-a1d4-track-a1.md
│   └── WO-20260810-33d1-track-c3.md
├── evidence/<ID>/                        wireframe snapshots
└── archive/YYYY/                          closed tickets
```

Grouping is by parent and never by status, because parent does not change over a
ticket's life and status changes five times. A layout that moved a file on every
transition would rot every path anyone had written down.

The tree is the same shape one level at a time: an epic reads down to its
children and no further, so a grandchild appearing never rewrites anything above
it.

| Question                        | Answer                                                      |
| ------------------------------- | ----------------------------------------------------------- |
| What may I start right now?     | `work-order.sh next` - `ready` with every dependency `done` |
| What is the shape of this work? | `work-order.sh tree`, or the Tree section of `INDEX.md`     |
| Where does this ticket sit?     | `parent` in its frontmatter; the path follows from it       |
| What is it waiting on?          | `depends_on`, and the "waiting on" column in `INDEX.md`     |
| What happened while it ran?     | its `## Notes` section, appended by `work-order.sh note`    |

`depends_on` is the authoritative direction and `blocks` is its inverse. Both are
written when an edge is made, so a ticket read on its own is enough to tell an
agent whether it is allowed to start. Every edge that would close a cycle is
refused - a dependency loop makes `next` permanently empty, which reads exactly
like "there is no work" and is the worst failure this graph can have.

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

`link`, `note`, `next`, `tree` and `reindex` sit outside the status set: they
change the graph, the record, or the view, never the state. So none of them can
advance a ticket, and none of them is blocked by one.

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

### Cutting an epic and its children

An epic is a ticket whose closure depends on its children. Mint the parent first,
then each child with `--parent`, then wire the ordering with `--depends-on`:

```bash
EPIC=$(bash $WO new --json --type feature --priority p1 \
  --title "Dev pipeline test end to end" --problem "..." --out "real money" \
  --ac "the run script exits 0 from a clean environment" | jq -r .id)

RUNNER=$(bash $WO new --json --parent "$EPIC" --type feature \
  --title "Contract test runner" --problem "..." --out "..." --ac "..." | jq -r .id)

# ordering the children, once every ID exists
bash $WO link --id "$CONSOLE" --depends-on "$RUNNER"

bash $WO next --json      # <- what an agent may pick up, and nothing else
bash $WO tree             # <- the shape, for a human
```

`link` is the only way to add an edge after the fact, which is the normal case:
siblings cannot reference each other at mint time. It moves the file when the
parent changes, with `git mv`, and carries any descendants along.

### Notes: the progress record

```bash
bash $WO note --id WO-20260805-3f2a --text "namespace up, storefront pod pending"
```

Appended newest-first under `## Notes`, stamped, never rewritten - the same rule
as `ISSUES.md`. This is the **only** way a note reaches a ticket. An agent that
hand-edits the file instead defeats the format ownership the whole skill rests on,
and on a repository with a markdown formatter hook it corrupts the JSON
frontmatter outright.

Notes are for what happened. A decision that changes the work belongs in the
ticket's own fields, and a new idea belongs in `BACKLOG.md`.

### The index as a gate

`INDEX.md` is generated and leads with what is startable, because the question an
agent arrives with is "what may I pick up". Wire the gate into the commit hook:

```bash
bash $WO reindex --check   # exit 3 when INDEX.md and the tickets disagree
```

A stale index is not cosmetic. It is the router the next agent reads, and one that
disagrees with the tickets on disk sends work to the wrong place.

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

Cases 110-130 cover the hierarchy, the dependency graph, notes, and the index
gate. The assertions that earn their keep are the refusals: an edge to a missing
ticket, a cycle in either direction, a re-home that would leave a grandchild
behind, and an index that drifted.

## Bundled resources

- `references/lifecycle.md` — the full status table: setter, gate, legal successors, what it writes, what makes it refuse.
- `references/ticket.tmpl` — the body skeleton. `new` fills it; nobody edits a ticket by hand.
- `scripts/work-order.sh` — every subcommand.
- `scripts/lib/wo.sh` — identity, frontmatter, hierarchy, the graph, wireframe binding.
- `scripts/lib/common.sh` — vendored from project-scaffold so this skill is independently consumable.
- `settings.json.tmpl`, `settings.local.json.tmpl` — allowlist the script, and deliberately do **not** allowlist raw `git branch -D` / `git push --delete`, so hand-rolled cleanup is not an available path.
