---
name: cartography
description: Map a complex system top-down into 3-7 "islands" and generate standalone, locally hostable HTML documents with embedded Mermaid diagrams - each island's execution tickets minted as real work-orders. Use when the user asks to map out, architect, or break down a system, business, or process from the ground up; asks for an island map, a macro map, a system blueprint, or "where do I even start with this"; wants architecture documentation as self-contained HTML; or says "map this out" / "break this into modules" / "cartography". Not for wireframing a UI - that is figma-wireframe. Not for ticketing work that is already understood - that is work-order on its own.
version: 1.0.2
---

# Cartography

> **This copy is read-only.**
> Skills are vendored into a project as copies, and this may be one.
> Edit this skill upstream, bump its version, then re-pull it - never edit the copy where it landed.
> Upstream is https://raw.githubusercontent.com/jkkelley/dotfiles/refs/heads/main/claude/skills/cartography/SKILL.md, and `skill-update.sh` pulls it from there - no dotfiles checkout is needed on this machine.
> `skill-update.sh` replaces the skill's directory rather than merging into it, so a local edit is destroyed by the next update with no conflict and no warning.
> The registry's content hash cannot catch it either, because a project's copy legitimately differs from upstream.

Top-down maps of a system, drawn as standalone HTML, where every execution
ticket on the page is a **real work-order that already exists**.

The whole skill turns on one idea: an ID minted during planning. You do not know
what the work is yet - that is why you are drawing a map - but you know _where_
it goes. So the ticket is issued at planning time, in `draft`, with its open
questions written down, and the map points at it. The next agent arrives to a
slot that already has an address instead of a paragraph of prose it has to
re-interpret.

The determinism comes from the same rule work-order rests on, extended one step:

| Who        | Owns                                            |
| ---------- | ----------------------------------------------- |
| the model  | what the islands are, the prose, the Mermaid    |
| this skill | every HTML byte, every path, the ledger         |
| work-order | every ticket byte, and every ID in the document |

`cartograph.sh` never writes ticket markdown. It shells out to `work-order.sh`
for each mint and reads the ID back from `--json`. An ID the model typed would
be a dangling pointer the moment anyone clicked it, and the click is the whole
point of the map.

## Requirements

- `bash` 4+, `jq`.
- **work-order**, as a sibling skill directory, at `$CARTO_WORK_ORDER`, or via
  `--work-order PATH`. There is no degraded mode: a map whose tickets were
  written by anything else is a map of tickets that do not exist.

## What a skeleton ticket is

A skeleton is **structurally complete and semantically open**. It has a title, a
problem, non-goals, and at least one acceptance criterion. What it does not have
is the detail, and that absence is recorded as `--question` rather than left
blank.

This shape is forced by work-order, not chosen for taste. `--ac` is accepted at
mint time only - `cmd_new` is its sole writer, and `evidence` only _ticks_ boxes
that already exist. A ticket minted with no criterion therefore can never be
approved and no later command can repair it. `cartograph.sh` refuses that spec
outright rather than issuing a ticket that is dead on arrival.

The payoff is that a skeleton needs no new gate. work-order's existing ones
already hold it shut:

| Gate                                       | Consequence                                          |
| ------------------------------------------ | ---------------------------------------------------- |
| `approve` refuses while a question is open | a skeleton cannot be mistaken for ready work         |
| `next` returns only `ready`                | skeletons are invisible to an agent hunting for work |
| `resolve` demands an answer                | it is the verb that graduates a skeleton             |

So a skeleton can sit in the tree indefinitely and cost nothing. Answer its
questions with `work-order.sh resolve` and it becomes an ordinary ticket.

## How the directory is organised

```
<project>/
├── cartography/
│   ├── .map.json                    key -> work-order id. Generated.
│   ├── specs/                       the model's authored input, stored
│   │   ├── macro.json
│   │   └── ingestion.json
│   ├── 000-macro-map.html           the island map + the ledger
│   └── 003-product-ingestion.html   one island
└── work-orders/                     owned entirely by work-order
    ├── INDEX.md
    ├── WO-...-dropshipping-platform.md          the system epic
    └── WO-...-dropshipping-platform/
        ├── WO-...-product-ingestion.md          an island epic
        └── WO-...-product-ingestion/
            ├── WO-...-scraper-adapters.md       a ticket
            └── WO-...-ingestion-orchestrator.md a skeleton
```

The hierarchy is the map. A system epic holds island epics, which hold tickets,
which is exactly the shape work-order's `tree` and `INDEX.md` already render - so
the HTML is a _second_ view of a structure that is authoritative on disk, never
the structure itself. Delete `cartography/` entirely and nothing about the work
is lost.

Specs are stored because `render` has to run later without being re-supplied.
The overview prose and the Mermaid live nowhere else; ticket state is re-read
from work-order every time.

## The phases

Full protocol, including what to say at each gate, is in `references/phases.md`.

| Phase | What happens                                                      | Gate                            |
| ----- | ----------------------------------------------------------------- | ------------------------------- |
| 1     | Break the system into 3-7 islands, draw the macro Mermaid         | user approves before any mint   |
| 2     | One island at a time: diagram it, mint its skeleton tickets       | user approves each island first |
| 3     | Hand off. `resolve` the questions, then the normal work-order run | work-order's own lifecycle      |

Phase 2 is strictly sequential and that is deliberate. Generating six islands at
once produces six documents nobody read, and the tickets underneath them are
real - a rejected island that was already minted leaves orphans to clean up by
hand.

## Usage

```bash
CG=.claude/skills/cartography/scripts/cartograph.sh

# Phase 1 - after the user approves the island breakdown
bash $CG plan --project . --spec cartography-macro.json

# Phase 2 - one island at a time, after the user approves each
bash $CG island --project . --spec cartography-ingestion.json

# Any time afterwards - re-read every ticket and rebuild the HTML
bash $CG render --project .
bash $CG ledger --project . --json
```

Every subcommand takes `--project DIR`, `--json`, `--help`. Exit codes match
work-order: `0` ok, `2` usage, `3` validation, `4` io/missing dependency, `6` id
not found.

`plan` runs once per system and refuses a second run. A duplicate system epic
over the same map is the one mistake `link` cannot undo. `island` likewise
refuses an island that already has tickets: minting again would issue new IDs
for the same work and orphan the first set, with nothing pointing at them.

### The spec format

The model writes JSON; the script writes everything else. `cartograph.sh --help`
carries both schemas in full. The fields that matter:

- `ac` is **required** on the system, on every island, and on every ticket, for
  the reason above. State what done looks like however coarsely.
- `questions` is where the parts you cannot yet state go. This is what makes a
  ticket a skeleton.
- `depends_on` takes a bare key for a sibling in the same island, `island/key`
  to reach across islands, or a raw `WO-` id. Edges are wired after every ID
  exists, because a sibling cannot be referenced at mint time.
- `mermaid` and `overview` go into the page raw. Mermaid labels legitimately
  carry `<br>`, and a diagram whose arrows had been escaped would not render.
  Everything read back out of a ticket _is_ escaped.

### render is the honesty mechanism

`render` mints nothing and re-reads every ticket, so the badge on the page is the
status in the tree rather than the status at the moment the page was written. Run
it whenever work has moved. A map that froze its statuses at generation time
would be lying within a day, and it would be lying in the direction that matters
most - a document that still says `draft` over finished work.

The File Tracking Ledger is generated the same way, from the tickets rather than
from the spec that requested them. A hand-maintained count is wrong the moment
anything moves and nothing ever catches it.

## Working with the other skills

| Skill                | Relationship                                                                                                                                                             |
| -------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **work-order**       | Downstream and authoritative. Every ticket, every ID, every status. Cartography only reads back.                                                                         |
| **figma-wireframe**  | Orthogonal. If an island is a UI, wireframe it and cut that island's tickets with `--from-figma` directly through work-order; cartography does not proxy the figma path. |
| **project-scaffold** | `BACKLOG.md` is for ideas nobody has scheduled. An island is scheduled by definition - it has an epic.                                                                   |

## Testing

`bash testing/run-tests.sh`. Podman, `--network=none`, skills mounted read-only,
per root CLAUDE.md Rule 14. The base image is pinned by digest per Rule 15.

The mount is the _skills_ directory rather than this skill alone, deliberately.
cartograph finds work-order as a sibling, and a suite that mounted work-order
somewhere artificial and pointed `CARTO_WORK_ORDER` at it would leave the real
resolution path - the one every user hits - untested. The "no work-order
anywhere" refusal is tested by copying the skill somewhere without a sibling,
for the same reason: a bad `--work-order` flag alone falls through to the sibling
and proves nothing.

Case 030 is the one that justifies the skill. Its load-bearing assertions are not
about HTML at all: that `approve` refuses a skeleton, that the sibling _without_
an open question is approved (so the refusal is about the question, not about
cartography-minted tickets in general), that `next` never offers a skeleton, and
that `resolve` graduates it. If those ever pass, cartography is minting tickets
an agent can pick up as real work before anyone has written the work.

Every refusal case also asserts its side effects, not only its exit code. A
half-planned system - a system epic with some of its islands, and a `.map.json`
that blocks the retry - is the worst state this script could leave behind, so
each refusal is checked for having minted nothing at all.

Case 040 asserts a re-render is byte-identical when nothing moved _and_ not
identical when a ticket did move. A renderer that cached would pass the first
check and be useless.

## Bundled resources

- `references/phases.md` — the three-phase protocol, what to ask at each gate, and the spec schemas with a worked example.
- `references/island.tmpl` — the page skeleton. A `%%TOKEN%%` added here without a matching case in `render_page` makes rendering refuse rather than ship the placeholder, for the same reason work-order guards its ticket template.
- `scripts/cartograph.sh` — every subcommand.
- `scripts/lib/common.sh` — vendored from project-scaffold so this skill is independently consumable.
- `settings.local.json.tmpl` — allowlists `cartograph.sh` as a whole, so a new subcommand needs no permission change.
