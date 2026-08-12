# The three phases

The protocol exists to stop one failure: generating a pile of documents nobody
read, backed by tickets nobody asked for. Every phase ends at a gate, and the
gate is a real stop - not a rhetorical "shall I continue?" while already halfway
into the next file.

---

## Phase 1 - macro discovery

**Input:** a core concept or system goal, in the user's own words.

**Do:**

1. Break the system into **3-7 islands**. Fewer than three is not a map, it is a
   title. More than seven means the boundaries are wrong - look for the two that
   are really one, or the one that is really a whole system of its own.
2. Give each island a `key` (kebab-case, stable, how every later command
   addresses it) and a `number` (its position in the flow, not its priority).
3. Draw the macro Mermaid flowchart showing how the islands interact. The arrows
   here become `depends_on` edges, so draw the ones you mean.
4. Present the breakdown and the diagram **as a message, not as a file**.

**Gate:** wait for approval. Nothing is minted, no directory is created.

An island boundary is right when a change inside one island does not force a
change inside another. If two islands always change together, they are one
island. If explaining island A requires explaining half of island B, the seam is
in the wrong place.

---

## Phase 2 - micro blueprinting

One island at a time. In order. Never in a batch.

**Do, per island:**

1. Draw the island's internal logic as one or more Mermaid diagrams - a
   flowchart for a pipeline, a sequence diagram for a protocol, a class diagram
   for a normalisation layer.
2. Write the execution tickets as spec JSON. Each one needs a `problem`, at
   least one `out`, and at least one `ac`. Everything you cannot yet state goes
   in `questions`.
3. Present the ticket list **as a message** - titles and one-line problems.

**Gate:** wait for approval of _that island_, then run `cartograph.sh island`.

The minting is what makes this gate real. A rejected island that was already cut
leaves orphan tickets in the tree that someone has to clean up by hand, and
`island` refuses to re-cut so the fix is not a re-run.

After the mint, present the generated file path and the ledger. Then stop again,
before the next island.

---

## Phase 3 - handoff

The map is done and the tickets exist. From here it is ordinary work-order:

```bash
WO=.claude/skills/work-order/scripts/work-order.sh

bash $WO next --project .                          # what may be picked up
bash $WO resolve --id WO-... --index 1 --answer "" # graduate a skeleton
bash $WO approve --id WO-...                       # after Lavish review
```

Re-render whenever work has moved, so the map keeps telling the truth:

```bash
bash .claude/skills/cartography/scripts/cartograph.sh render --project .
```

---

# Spec schemas

## Macro spec

```json
{
  "system": {
    "title": "Dropshipping platform",
    "problem": "The parts have never been drawn together.",
    "out": ["anything requiring a supplier contract"],
    "ac": ["every island has a document and at least one ticket"],
    "questions": ["is there a budget ceiling for hosting?"]
  },
  "overview": "<p>Six islands, one pipeline.</p>",
  "mermaid": "graph TD\n  A[Ingestion] --> B[Storefront]",
  "islands": [
    {
      "key": "ingestion",
      "number": 3,
      "title": "Product Ingestion",
      "summary": "Turns a supplier URL into a normalised product record.",
      "problem": "Supplier data arrives in incompatible shapes.",
      "out": ["storefront rendering"],
      "ac": ["a supplier URL yields a valid product record"],
      "depends_on": []
    }
  ]
}
```

`overview` and `mermaid` are optional. Everything else on an island is required
except `depends_on`, `questions`, `summary` and `type`.

## Island spec

```json
{
  "island": "ingestion",
  "overview": "<p>Delegates extraction, normalises, publishes.</p>",
  "diagrams": [
    {
      "caption": "The pipeline",
      "mermaid": "graph TD\n  T[URL] --> O[Orchestrator]"
    }
  ],
  "tickets": [
    {
      "key": "scrapers",
      "title": "Scraper adapters",
      "type": "feature",
      "priority": "p1",
      "problem": "Each supplier exposes a different DOM.",
      "in": ["headless browser scripts"],
      "out": ["bot-protection bypass"],
      "ac": ["a known supplier URL yields title, cost and image URIs"],
      "test_plan": "podman run --rm node:22 npm test -- scrapers"
    },
    {
      "key": "orchestrator",
      "title": "Ingestion orchestrator",
      "problem": "Nothing routes a URL to the right scraper.",
      "out": ["scraping itself"],
      "ac": ["a POST with supplier_id reaches the matching adapter"],
      "questions": ["is this an n8n webhook or a pod on the cluster?"],
      "depends_on": ["scrapers"]
    }
  ]
}
```

`type` defaults to `feature` and must be one of work-order's set: `feature`,
`bug`, `chore`, `spike`. `priority` must be `p0`-`p3`.

`depends_on` resolution, in order:

| Form         | Means                           |
| ------------ | ------------------------------- |
| `scrapers`   | a sibling ticket in this island |
| `other/key`  | a ticket in another island      |
| `WO-2026...` | a raw work-order id             |

---

# Writing a good skeleton

The difference between a useful skeleton and a useless one is entirely in what
goes in `ac` versus what goes in `questions`.

**`ac` is what would be true if this were done.** You almost always know this at
planning time, because it is why you drew the box. "A POST with `supplier_id`
reaches the matching adapter" is knowable before you have decided whether the
thing is a webhook or a pod.

**`questions` is what you would have to decide before starting.** Not what you
would have to _build_ - what you would have to _decide_. "n8n webhook or a pod on
the cluster" is a question. "Write the routing logic" is not a question, it is
the work.

A ticket whose acceptance criteria you genuinely cannot state is a sign the
island boundary is wrong, or that the ticket is really two tickets. Splitting it
is the fix. Minting it with a vague criterion so the gate passes is how a ticket
reaches `done` without anyone having verified anything.
