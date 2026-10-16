---
{
  "id": "WO-20261016-f052",
  "slug": "validate-schema-sh-resolves-ref-offline-from-a-l",
  "title": "validate-schema.sh resolves $ref offline from a local registry of the repo schema files, keyed by $id",
  "type": "feature",
  "status": "ready",
  "priority": "p0",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T09:29:46+00:00",
  "parent": "WO-20261016-41d0",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "infra-design10 cut for ORD-0830 RR-orch-14 and ORD-0921; design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": [
    "WO-20261016-efb2"
  ],
  "ac_checks": [
    {
      "index": 1,
      "command": "podman run --rm --network=none --userns=keep-id -v \"$PWD:/work:Z\" -w /work/claude/workflow -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash tests/unit/test_validate_schema_ref.sh",
      "exit": 0,
      "expect": "ok  repo-ref: node bundle resolved offline"
    },
    {
      "index": 2,
      "command": "make -C claude/workflow schema",
      "exit": 0,
      "expect": null
    },
    {
      "index": 3,
      "command": "make -C claude/workflow lint",
      "exit": 0,
      "expect": null
    },
    {
      "index": 4,
      "command": "grep -c schema_registry.py claude/workflow/tools/validate-schema.sh",
      "exit": 0,
      "expect": "^[1-9]"
    },
    {
      "index": 5,
      "command": "git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/workflow/tools/schema_registry[.]py|claude/workflow/tools/validate-schema[.]sh|claude/workflow/tests/unit/test_validate_schema_ref[.]sh|claude/workflow/tests/unit/test_workflow_schemas[.]sh)$'",
      "exit": 1,
      "expect": null
    }
  ],
  "provides": []
}
---

# WO-20261016-f052 - validate-schema.sh resolves $ref offline from a local registry of the repo schema files, keyed by $id

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

claude/workflow/tools/validate-schema.sh builds Draft202012Validator(schema) with no registry, so any relative $ref is fetched over the network. Under --network=none (every test, Rule 14) claude/workflow/dag/schemas/node.schema.json property bundle {"$ref": "bundle.schema.json"} (base $id https://dag.invalid/) fails with jsonschema.exceptions.RefResolutionError <urlopen error [Errno -3] Temporary failure in name resolution> for every node file whatever its content. It blocked seat dag-t6b on WO-20261016-efb2 - dag-state T6 - Intake node declarations N1 to N10 (DESIGN-GAP).

## Owner words

> if the task or job needs tools, the architect has a design agent build that shit out before the ticket goes in, thats a prereq for the ticket ready then (Design principles 101 item 30)

> create generic tooling too fucker (item 30)

> Have fallbacks too (item 28)

## Context

Order ORD-0921 E3 (brief BR-20261016-infra-design10): one shared helper in claude/workflow resolves JSON Schema $ref from a local registry built from the repo schema files, each keyed by its $id, never the network; validate-schema.sh uses it.

Evidence: seats/dag-t6b.result.json (inbox-triage/20261015). Repro from the repo root: echo {"bundle":5} > /tmp/n.json in the pinned image, then bash claude/workflow/tools/validate-schema.sh claude/workflow/dag/schemas/node.schema.json /tmp/n.json under podman --network=none -> RefResolutionError.

Inventory, 2026-10-16 on main 17dc5b6: the pinned test image localhost/dotfiles-workflow-test:1 (claude/workflow/tests/container/Containerfile, Debian python3-jsonschema) carries jsonschema 4.10.3 and NO referencing module, so referencing.Registry (jsonschema >= 4.18) is unavailable there. jsonschema 4.10.3 RefResolver(base_uri=schema $id, referrer=schema, store={$id: schema}) resolves it: prototyped in that image with --network=none, {"bundle":5} against node.schema.json printed bundle: 5 is not of type 'object' and exit 1 (the bundle schema was applied). Callers of validate-schema.sh with two args: claude/workflow/bin/brief.sh:30, bin/workflow-lib.sh:83, bin/seat-record.sh:79 (copies the schema to a tmp dir, so the registry must come from the repo, not the schema file's own directory), dag/bin/dag-lib.sh:25, inbox-sweep/bin/sweep-init.sh, sweep-watch.sh. Every $id under claude/workflow/**/*.schema.json is unique today (24 files).

Design, fixed: new claude/workflow/tools/schema_registry.py, stdlib + jsonschema only. build_store(roots) globs <root>/**/*.schema.json for each root, loads each, keys it by its $id (a file with no $id is skipped); two files with one $id and unequal bodies: stderr 'REF-DUP-ID <id> <path1> <path2>', exit 2. Implementation from env SCHEMA_REF_IMPL, default auto: auto tries import referencing and builds referencing.Registry().with_resources([(id, Resource.from_contents(s, default_specification=DRAFT202012)) ...]) passed as registry=; on ImportError it takes the fallback RefResolver(base_uri=schema.get('$id',''), referrer=schema, store=store, handlers={'http': refuse, 'https': refuse}) passed as resolver=, where refuse raises so a miss can never fetch. SCHEMA_REF_IMPL=registry with referencing missing: stderr 'REF-IMPL-MISSING referencing', exit 2. SCHEMA_REF_IMPL=resolver: always the RefResolver path. A ref no store entry holds (RefResolutionError, or referencing Unresolvable) is caught: stderr 'REF-UNRESOLVED <ref>', exit 2. Roots: env SCHEMA_REGISTRY_ROOTS, colon-separated, default the claude/workflow directory (parent of tools/). validate-schema.sh keeps its usage and exits (0 valid, 1 invalid, 2 usage or registry error) and replaces its inline python with python3 "$HERE/schema_registry.py" "$1" "$2", HERE being the script's own directory; schema_registry.py's __main__ prints each error as today (' <path>: <message>' to stderr, sorted by path).

## Scope

**In**

- touches: claude/workflow/tools/schema_registry.py (new: store, implementation choice and main exactly as fixed in Context; a header comment naming WO-20261016-efb2, seat dag-t6b and why the 4.10.3 RefResolver fallback exists)
- touches: claude/workflow/tools/validate-schema.sh (the python3 -c block only, replaced by the schema_registry.py call; a breadcrumb comment: what broke (RefResolutionError under --network=none on the node.schema.json bundle $ref), why a local store (no gate has a network), the rejected alternative (inlining bundle into node.schema.json: every future $ref repeats the gap), cost (one glob of claude/workflow per call))
- touches: claude/workflow/tests/unit/test_validate_schema_ref.sh (new: cases TP-1 to TP-5 printing exactly the ok lines the test plan names, FAIL lines otherwise, in the style of test_workflow_schemas.sh, exit 1 on any FAIL; tmp dir from mktemp -d removed by a trap)
- touches: claude/workflow/tests/unit/test_workflow_schemas.sh (one line before its final exit: bash "$R/tests/unit/test_validate_schema_ref.sh" || fail=1, so make schema and CI run the new cases)
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: branch from origin/main in your own worktree; make exactly the four edits above
- step: make -C claude/workflow image; then from the repo root podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work/claude/workflow -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash tests/unit/test_validate_schema_ref.sh; then make -C claude/workflow schema lint; nothing else locally, CI runs the rest
- step: commit 'feat(workflow): validate-schema.sh resolves $ref from a local schema registry, offline (ORD-0921 E3)' with the ticket id; no Bump trailer (no file under claude/skills changes)
- tool: make:claude/workflow/Makefile:image, schema, lint - on main; fallback: make missing on the host: run the podman command of the AC-H1 check for each test file; podman missing: stop with ENV-MISSING
- tool: lib:python3-jsonschema 4.10.3 in the pinned image - fallback: referencing absent is the designed fallback (RefResolver store, TP-5); jsonschema absent: stop with ENV-MISSING naming it
- tool: cmd:git, cmd:gh - fallback: missing on the host: stop with ENV-MISSING; GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- inlining or editing any *.schema.json, node.schema.json included
- changing validate-schema.sh's argument contract or exit codes
- any network retrieval of a schema, any pip install or image change
- the N1 to N10 node files of WO-20261016-efb2
- work-orders/INDEX.md and epic READMEs by hand or by git add; waiting on CI or merging: push, open the PR, write the result, leave
- any file not named under In: stop with DESIGN-GAP

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* the new cases pass in the pinned image with no network
  - check: `podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work/claude/workflow -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash tests/unit/test_validate_schema_ref.sh` exit 0 expect /ok repo-ref: node bundle resolved offline/
- [ ] `AC-H2` *(human)* the existing schema suite still passes
  - check: `make -C claude/workflow schema` exit 0
- [ ] `AC-H3` *(human)* shellcheck clean
  - check: `make -C claude/workflow lint` exit 0
- [ ] `AC-H4` *(human)* validate-schema.sh calls the shared helper
  - check: `grep -c schema_registry.py claude/workflow/tools/validate-schema.sh` exit 0 expect /^[1-9]/
- [ ] `AC-H5` *(human)* the diff holds only the four named files and work-orders files
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/workflow/tools/schema_registry[.]py|claude/workflow/tools/validate-schema[.]sh|claude/workflow/tests/unit/test_validate_schema_ref[.]sh|claude/workflow/tests/unit/test_workflow_schemas[.]sh)$'` exit 1

## Test plan

{"scope":"validate-schema.sh resolves $ref offline from a local registry of the repo schema files","cases":[ {"id":"TP-1","intent":"the DESIGN-GAP of seat dag-t6b: node.schema.json bundle $ref must resolve with no network, and the referenced schema must really be applied (a bundle of the wrong type fails on bundle, not on a resolver error)","command":"bash tests/unit/test_validate_schema_ref.sh","expected":"exit 0; prints ok repo-ref: node bundle resolved offline"}, {"id":"TP-2","intent":"two tmp schemas, a.schema.json with $ref b.schema.json, under SCHEMA_REGISTRY_ROOTS=<tmp>: a valid instance exits 0 and an invalid one exits 1","command":"bash tests/unit/test_validate_schema_ref.sh","expected":"exit 0; prints ok roots: valid 0, invalid 1"}, {"id":"TP-3","intent":"a $ref to an $id no root holds stops with REF-UNRESOLVED and exit 2, never a network fetch or a traceback","command":"bash tests/unit/test_validate_schema_ref.sh","expected":"exit 0; prints ok unresolved: exit 2 REF-UNRESOLVED"}, {"id":"TP-4","intent":"two files with one $id and different bodies make the registry ambiguous: exit 2 REF-DUP-ID naming both paths","command":"bash tests/unit/test_validate_schema_ref.sh","expected":"exit 0; prints ok dup-id: exit 2 REF-DUP-ID"}, {"id":"TP-5","intent":"fallback path: the pinned image ships jsonschema 4.10.3 with no referencing module, so SCHEMA_REF_IMPL=auto takes the RefResolver store fallback; SCHEMA_REF_IMPL=registry with referencing missing exits 2 REF-IMPL-MISSING","command":"bash tests/unit/test_validate_schema_ref.sh","expected":"exit 0; prints ok fallback: resolver store used, registry missing exit 2"}, {"id":"TP-6","intent":"every existing caller (brief.sh, workflow-lib.sh, seat-record.sh, dag-lib.sh) keeps the two-argument contract and exit 0/1","command":"bash tests/unit/test_workflow_schemas.sh","expected":"exit 0"}], "isolation":{"runtime":"podman","image":"docker.io/library/debian@sha256:328d16499860ae6cb9b345e2e4cebca08c2a36e4f7278482c7bd1f39d71e5bfd"}, "out_of_scope":["the full claude/workflow suite: CI runs it","WO-20261016-efb2 node files: that ticket validates them after this merges"]}

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
