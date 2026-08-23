# Change triggers

Diataxis mode: **reference**.
Last reviewed: 2026-08-23.

The table that says which document moves when something changes.

It exists so the decision does not have to be made at the moment of forgetting.
Copy it into a project and adjust the left column to that project's shape; the right column rarely changes.

## The table

| Touched this | Update this | Why |
| --- | --- | --- |
| A public function signature, flag, or CLI argument | `docs/reference/` | The reference mirrors the machinery. A stale signature is a lie the reader cannot detect |
| The steps an operator performs | `docs/sops/` | An SOP that no longer matches is worse than none, because it is trusted |
| An architectural choice, or the reversal of one | `docs/decisions/` as a new ADR | Superseded, never edited |
| The shape of stored data, a schema, a file format | `docs/reference/` and an ADR if the change is not backward compatible | Consumers need both the new truth and the reason |
| The first-run or install path | `docs/tutorials/` | The one document a beginner cannot recover from |
| A dependency version that changes behaviour | `docs/reference/` | Version-sensitive behaviour is a fact, not a story |
| A design rationale that turned out to be wrong | `docs/explanation/` | The only mode allowed to argue is the one that has to be corrected when the argument loses |
| Nothing user-visible | nothing | Not every change earns a document. Saying so explicitly is what keeps the rest credible |

## How this is enforced

Not by this table.
The table is a lookup, and a lookup nobody consults enforces nothing.

The enforcement is on the ticket: every work-order carries a documentation acceptance criterion, and `work-order` refuses to mark a ticket `done` without `--observed` evidence for each one.
The table exists so that filling in the acceptance criterion takes ten seconds instead of a debate.

## The one rule that has no table entry

**If you changed the system and cannot name the document that should move, that is the finding.**
Either the document does not exist yet and should, or the change is genuinely invisible and the ticket says so.
Both are answers. Silence is not.
