_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

<the one unit this ticket changed - a script, a verb, a function - in one line>

**Cases**

- `TP-1`
  - intent: <why it matters - what breaks, and for whom, if this case fails>
  - command: `<the exact command, run inside the isolation below>`
  - expected: <the exit code and the observable result a reader can check>

**Isolation**

- runtime: podman
- image: `<registry>/<name>@sha256:<64 hex digest>` (<human tag at pin time>)

**Out of scope - CI covers**

- <what full integration CI runs instead, so this plan stays small>
