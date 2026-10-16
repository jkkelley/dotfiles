---
{
  "id": "WO-20261016-9821",
  "slug": "a2a-yp-brief-sh-migrate-upgrades-yp-brief-0-and-",
  "title": "A2A-YP: brief.sh migrate upgrades yp-brief/0 and yp-result/0 to zenith.a2a.brief.v1 and zenith.a2a.result.v1",
  "type": "feature",
  "status": "draft",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T07:00:40+00:00",
  "parent": "WO-20261016-0272",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": null,
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-bcb4"
  ],
  "blocks": [
    "WO-20261016-87b6"
  ],
  "labels": [
    "line:inbox-triage"
  ]
}
---

# WO-20261016-9821 - A2A-YP: brief.sh migrate upgrades yp-brief/0 and yp-result/0 to zenith.a2a.brief.v1 and zenith.a2a.result.v1

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

Orchestrator order O1 of MSG-20261016T064822Z-yp-design (2026-10-16 UTC): 'briefs name a state_file with no content spec, and yp results use schema yp-result/0, not zenith.a2a.result.v1 (brief.sh result-check fails); align the yp brief/result template.' Facts: yp-line's seat briefs (for example lif04c-brief.json in /home/luna/.local/state/zenith/inbox-triage/20261015/seats) carry schema yp-brief/0 with a state_file path and a result_shape of schema yp-result/0; the state files actually written are JSONL rows {step, status, at, proof} (f08-state.json); no schema or template in dotfiles names either shape. Owner item 18: 'agent to agent prose sucks, schemas with defined AC always'. Owner item 30: 'so its re-usable, add to it, makefiles, dont' be a crackhead and one off shit all the time': this adds a verb and two migrations to brief.sh, the existing tool.

## Scope

**In**

- touches: claude/workflow/bin/brief.sh
- touches: claude/workflow/migrations/brief/yp-brief_0.jq (new)
- touches: claude/workflow/migrations/brief/yp-result_0.jq (new)
- touches: claude/workflow/a2a.mk
- touches: claude/workflow/tests/unit/test_a2a_migrate_yp.sh (new)
- touches: claude/workflow/tests/fixtures/a2a/ (new: yp-brief.json, yp-result.json copied from lif04c-brief.json and lif04c-result.json)
- step: brief.sh cmd_migrate: the chain stops when .schema is zenith.a2a.brief.v1 or zenith.a2a.result.v1 (RESULT_SCHEMA_ID beside BRIEF_SCHEMA_ID); every jq call also gets `--arg at "$(date -u -r "$file" +%Y-%m-%dT%H:%M:%SZ)"` (the file's mtime in UTC, so a rerun is byte-identical) and `--arg name "$(basename "$file" .json | sed -E 's/-(brief|result)$//')"`
- step: yp-brief_0.jq -> zenith.a2a.brief.v1: version $version; id "BR-" + (.ticket_id | ltrimstr("WO-")); at $at; kind request; status_code A2A-001; from {name: "yp-line", role: null}; to {name: $name, role: null}; subject .title; facts {ticket_id, ticket_file, repo, worktree, base_branch, branch, pr, touches, dag, rules, yp_result_shape: .result_shape} without nulls; actions .instructions; reply {required: true, format: "result JSON valid against zenith.a2a.result.v1 written to output.result_file"}; refs .read_first; acceptance_criteria by position: {id: "AC<n>", statement: .statement, proof_kind: (.proof_kind if in [command, file, url, screenshot] else "command"), proof: (.proof if non-empty else .statement)}; done_token "DONE " + $name; output {result_file: .result_path, state_file: .state_file}
- step: yp-result_0.jq -> zenith.a2a.result.v1: version $version; id "RS-" + (.ticket_id | ltrimstr("WO-")); at $at; kind notice; status_code A2A-002 when .status is pass, else A2A-003; from {name: $name, role: null}; to {name: "yp-line"}; subject (.ticket_id + " " + .status); brief_id "BR-" + (.ticket_id | ltrimstr("WO-")); status done when pass, else blocked; blockers .blockers; facts {ticket_id, pr_url, stubs, problems, yp_status: .status, yp_ac_ids: [.acceptance_criteria[].id]}; actions []; reply null; refs [.pr_url] without empty; acceptance_criteria by position {id: "AC<n>", ticked: (.verdict == "pass"), proof_kind: "command", proof: .evidence}; done_token "DONE " + $name + " " + .pr_url
- step: a2a.mk a2a-test's bash -c line also runs `shellcheck -x tests/unit/test_a2a_migrate_yp.sh && bash tests/unit/test_a2a_migrate_yp.sh`
- step: tests/unit/test_a2a_migrate_yp.sh, set -euo pipefail, one `ok <case>` line per case: (1) the migrated brief passes `brief.sh check`, (2) the migrated result passes `brief.sh result-check --brief <migrated brief>`, (3) a second migrate of the same files is byte-identical, (4) a yp-result with status fail migrates to status blocked and A2A-003 and result-check refuses it, (5) every key of the yp input survives somewhere in the output (facts, output or a mapped field)
- Tool: podman with a digest-pinned image (make -C ~/dotfiles/claude/workflow image builds localhost/dotfiles-workflow-test:1). Fallback: rerun with --pull=never on the locally cached image of the same digest. Switch: timed-run.sh --fallback ... --fallback-code FB-001 (status code FB-001; switch from WO-20261016-d304 - TR-FB)

**Out - non-goals**

- Changing who writes yp briefs: the writer runs `make -C ~/dotfiles/claude/workflow -f a2a.mk brief-migrate FILE= OUT=` or `brief-new`
- brief.schema.json and result.schema.json, unchanged here (A2A-ST adds state_file)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* `podman run --rm --network=none --userns=keep-id -v ~/dotfiles:/work:Z -w /work/claude/workflow -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash tests/unit/test_a2a_migrate_yp.sh` run from ~/dotfiles -> exit 0, output has 5 lines starting `ok` and no `FAIL`. Proof: command output
- [ ] `AC-H2` *(human)* `bash ~/dotfiles/claude/workflow/bin/brief.sh migrate /home/luna/.local/state/zenith/inbox-triage/20261015/seats/lif04c-result.json --out /tmp/r.json && bash ~/dotfiles/claude/workflow/bin/brief.sh migrate /home/luna/.local/state/zenith/inbox-triage/20261015/seats/lif04c-brief.json --out /tmp/b.json && bash ~/dotfiles/claude/workflow/bin/brief.sh result-check /tmp/r.json --brief /tmp/b.json` -> exit 0, last line starts `ok`. Proof: command output
- [ ] `AC-H3` *(human)* `FORCE_FALLBACK=1 bash ~/dotfiles/claude/workflow/bin/timed-run.sh --node a2a-yp --fallback "podman run --rm --pull=never --network=none --userns=keep-id -v ~/dotfiles:/work:Z -w /work/claude/workflow -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash tests/unit/test_a2a_migrate_yp.sh" --fallback-code FB-001 -- podman run --rm --network=none --userns=keep-id -v ~/dotfiles:/work:Z -w /work/claude/workflow -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash tests/unit/test_a2a_migrate_yp.sh` run from ~/dotfiles -> exit 0, stderr contains `FALLBACK FB-001`. Proof: command output

## Test plan

```sh
podman run --rm --network=none --userns=keep-id -v ~/dotfiles:/work:Z -w /work/claude/workflow -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash tests/unit/test_a2a_migrate_yp.sh
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
