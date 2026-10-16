---
{
  "id": "WO-20261016-ae19",
  "slug": "inbox-sweep-b21d-lead-ledger-sh-owns-leads-jsonl",
  "title": "Inbox sweep B21d - lead-ledger.sh owns leads.jsonl with an append verb",
  "type": "feature",
  "status": "in-progress",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T04:46:22+00:00",
  "parent": "WO-20261016-1703",
  "branch": "feat/inbox-sweep-b21d-lead-ledger-sh-owns-leads-jsonl",
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "Architect rulings R3 and R4, 2026-10-16T04:25Z, recorded in design 18 (PR 153); Claude seats never use lavish",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-b1b6",
    "WO-20261016-a47c"
  ],
  "blocks": [
    "WO-20261016-fc28",
    "WO-20261016-6242"
  ]
}
---

# WO-20261016-ae19 - Inbox sweep B21d - lead-ledger.sh owns leads.jsonl with an append verb

## Contents

- Problem
- Scope
- Degrees of freedom
- Acceptance criteria
- Test plan
- Assumptions
- Open questions
- Notes
- Outcome

## Problem

Ruling R3: leads.jsonl has three writers (lead-ledger.sh, lead-qualify.sh, lead-followup.sh), so it cannot be migrated by changing one file

## Scope

**In**

- files touched, and no others: claude/workflow/inbox-sweep/bin/lead-ledger.sh, bin/lead-qualify.sh, bin/lead-followup.sh, tests/unit/test_lead.sh, tests/unit/test_followup.sh

**Out - non-goals**

- touching a real LinkedIn thread, mailbox, the owner's Chrome or a real herdr session
- any step that works around the Claude Code auto mode classifier
- any file not listed in In

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* grep shows leads.jsonl written only by lead-ledger.sh (test greps bin/ for writes)
  - observed `2026-10-16` make -C claude/workflow/inbox-sweep test (Podman): suite lead ok, "AC-H1: no bin/ script but lead-ledger.sh writes leads.jsonl" ok, and "the writer pattern does catch a redirect into $LEADS" ok, so the check can fail; qualify and followup now write leads.jsonl only via lead-ledger.sh append
- [x] `AC-H2` *(human)* lead-qualify.sh and lead-followup.sh call lead-ledger.sh append and their suites stay green
  - observed `2026-10-16` make test: "AC-H2: lead-qualify.sh calls lead-ledger.sh append" ok, same for lead-followup.sh; suites lead, followup, lint, herdr-first all ok ("ran 4 suites", no FAIL)
- [x] `AC-H3` *(human)* lead-ledger.sh append is idempotent: the same row twice leaves one row (test)
  - observed `2026-10-16` make test: "AC-H3: the same row twice adds exactly one row" ok, "an updated row replaces, never duplicates" ok, malformed rows exit 2 with the file untouched, no lock left behind

## Test plan

```sh
make -C claude/workflow/inbox-sweep test (changed suites only, Podman, --network=none); CI runs lint and the full suite
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
