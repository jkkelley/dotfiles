# HYDRATION.md

The prompt that starts the next session, and the 10 before it.

**Read the top entry only.** It is the current one and it is complete on its own.
Everything below it has been superseded and is kept for history, not for reading.

**Newest on top.** Adding an entry removes the oldest in the same commit, so this
file holds exactly 10 once it has filled up. Entries are never renumbered and
never edited in place - a correction is a new entry.

Written by `hydration.sh add`. Do not hand-edit.
<!-- hydration-entry: WO-20260824-efb0 -->
## WO-20260824-efb0 - skill-sync.sh part two: build, swap, receipt, and self-update
_Generated 2026-08-24 by hydration.sh. Newest entry._

### Ticket

`WO-20260824-efb0` - `skill-sync.sh part two: build, swap, receipt, and self-update`.
Its only dependency, `WO-20260824-5b89` - `skill-sync.sh part one: resolution, and the tools test tree it is proved in`, is `done` and merged as PR #64.
`work-order next` returns it first.

It blocks three: `WO-20260824-2ad1` - `PR gate workflow: validate the bump intent and run the suites`, `WO-20260824-360d` - `Publish workflow: allocate versions on merge to main`, and `WO-20260824-bb0d` - `setup.sh installs the skill-sync binary, then the SessionStart hook`.

Poker put it at 8, the destructive half, sized above part one for the ownership matrix, the four failure modes and the self-update path.

### What just landed

`claude/tools/skill-sync.sh` exists at version `1.0.0`, with a `skill-tool-version:` marker and a `skill-sync` entry in the `tools` block of `claude/skills/registry.json`. `claude/tools/testing/` exists: `run-tests.sh` at 80 checks and a `Containerfile` on `debian@sha256:328d1649`, the same digest the `work-order` and `cartography` suites pin.

**It resolves and writes nothing, anywhere.** That is asserted, not asserted-by-intent: the suite hashes the whole project directory before and after a plan, a boot and a failed boot and compares.

What the script has today:

- `--boot`, `--plan`, `--help`, and a usage error on anything else. `--boot` is silent on both streams when there is no `.claude/skills.toml` here or the stamp is under 15 minutes old.
- `manifest_list`, reading `[skills]` and `[agents]`. Hand-rolled, one shape only.
- `fetch_registry`, three attempts and no sleep between them, returning 2 when `curl` is missing so that case gets its own sentence.
- `load_registry`, `json_array`, `json_string` - awk, no `jq`. `load_registry` is bounded to the skills block explicitly, because the tools block's entries have the same shape.
- `resolve`, breadth-first with a seen set. Cycles terminate.
- `emit_plan`, printing `owned` / `previous` / `dropped` / `unknown`, sorted, one tagged line per name.
- `sync_failed`, the two-line loud warning, on stdout because a hook's stdout reaches the agent's context and its stderr does not.

**The constants you need are already there and already right**: `MANIFEST=.claude/skills.toml`, `RECEIPT=.claude/cache/skills-receipt.json`, `STAMP=.claude/cache/.sync-stamp`, `STAMP_MAX_AGE=900`, `REGISTRY_URL`, `FETCH_ATTEMPTS=3`, and `NAME_RE`. Part one reads the receipt and the stamp and writes neither. They were put there so the two halves could not invent different paths for the same file - do not re-derive them.

`emit_plan` already computes `dropped`, which is exactly the set `AC-H2` turns on. You are wiring an answer that exists, not recomputing it.

Names are already validated against `NAME_RE` before they reach you, so a manifest saying `"../../etc"` never becomes a path. That check lives in `resolve` because a name becomes a directory in **your** half.

Before that: `WO-20260824-2136` - `Extract the read-only notice into a single rendered partial` put the notice in `claude/tools/partials/read-only-notice.md.tmpl`, and `WO-20260824-de9e` - `Registry schema 2, with type derived from the tree and requires read from frontmatter` gave every registry entry a derived `type` and a `requires`.

Suites at the moment you start: `claude/tools/` 80, `skill-versioning` 103, `work-order` 299 across 22 case files, repo-local `tools/` 36. All green in Podman on digest-pinned bases with `--network=none`.

### What is NOT done

Everything that writes. `grep -n 'mkdir\|rm -rf\|SKILL_SYNC_CHILD' claude/tools/skill-sync.sh` prints nothing.

- The stale `.claude/cache/.sync.*` sweep. **It was moved into your ticket** - see "Stale or false in the docs".
- The temp build, the notice render, the per-directory swap.
- Removing a dropped directory.
- The receipt write and the stamp write. Nothing writes `"status": "failed"` on the failure path yet; `sync_failed` prints and returns.
- The self-update path. `SKILL_SYNC_CHILD` appears nowhere in the repository.
- The `mkdir` lock. Part one takes no lock because it writes nothing.
- `--boot` currently ends by printing the plan and the line `skill-sync.sh: resolved N skills. This build resolves only and installs nothing.` **That line is yours to delete.** It is honest today and wrong the moment you install anything.

Still true and still on no ticket: branch protection is absent. `git ls-files .github/workflows` still prints nothing - the gate is `WO-20260824-2ad1` - `PR gate workflow: validate the bump intent and run the suites`, not you. The notice is still in all 43 `SKILL.md` files, which is epic 2.

Nothing was carried off part one. All three acceptance criteria were evidenced against the containerised run.

### Stale or false in the docs

**The `E1.6` seam moved, and the plan now says so.** `docs/superpowers/plans/2026-08-24-skills-package-manager-implementation.md` section `E1.6` has a horizontal rule in it marking the split. The five boxes above it are ticked. **The sweep box is below the rule, which means it is yours**, and that is one box higher than the hydration entry for part one implied.

The reasoning is on the ticket as a note, and it is worth reading before you argue with it: the sweep clears temp directories that only your half creates, so in part one it would have deleted nothing and no case in that suite could have produced a directory for it to find. A guard proved only against a fixture the code cannot generate is decorative.

The last three boxes in `E1.6` - always exit 0, always print loudly, and Rule 17 - are deliberately unticked. Part one honours all three. They stay open because you still owe them.

Both design documents still state the repository settings as `squash_merge_commit_message=COMMIT_MESSAGES`, `allow_merge_commit=true`, `allow_rebase_merge=true` - at `C2` in the plan and under `Repo settings, first` in the spec. All three were changed by `WO-20260824-cc71` - `Repo settings: squash-only, with the commit body taken from the PR description`.

Both also still carry the `SessionStart` matcher question as open, at `C7` and `E1.2` in the plan and under `Problem A` in the spec. It was answered by `WO-20260824-0615` - `Confirm whether a SessionStart hook matcher filters by source`: matchers do filter by source, alternation is honoured, the stdin-read fallback is dead. It bears on `WO-20260824-bb0d` - `setup.sh installs the skill-sync binary, then the SessionStart hook`, not on you.

Root `CLAUDE.md` Rule 16 does not bind this ticket. `claude/tools/` is not under `claude/skills/`, so no skill bump is owed. But `skill-sync.sh` is a registered tool with a `sha256` in the registry, so **editing it changes its hash and `skill-version.sh verify` goes red until you run `init`**. That is new since part one - the entry did not exist before. Bump the marker in the file's header yourself, then run `init`; the script owns the registry, never the marker.

Rule 17's `justfile` clause was read and deliberately not applied to `claude/tools/`, matching the repo-local `tools/` tree. The reasoning is a note on part one's ticket. It is flagged, not closed - only 2 of 43 skills carry one.

`workflows/close-out-procedure.md`, `claude/skills/work-order/SKILL.md` and root `CLAUDE.md` are all current on the close-out.

### Your scope

Everything destructive, and the ownership matrix is the part that has to be right.

- **Sweep** `.claude/cache/.sync.*` older than an hour, **before** starting. The one failure mode that skips the `trap` is a hook timeout, which is also the likeliest one.
- **Build into `.claude/cache/.sync.XXXXXX`**, render the notice into each `SKILL.md`, and swap each owned directory **individually**. A timeout mid-sync then leaves the previous state intact rather than half of it.
- **Remove a dropped directory only when the receipt claims it.** Never `rm -rf` the parent. `emit_plan`'s `dropped` tag is the input.
- **Write the receipt** with `owned` and `status`, and the stamp. `"status": "failed"` on the failure path too - `sync_failed` currently prints and nothing else.
- **Self-update**: `mv` to `.bak`, fork with `SKILL_SYNC_CHILD=1`, roll back on failure. `AC-H4` is the comment explaining why it is `mv` and not `cp`, and it is a deliverable in its own right.
- **Lock with `mkdir`**, which is atomic everywhere. Not `flock`.

Out: nothing in resolution needs revisiting, `.github/workflows/` is `WO-20260824-2ad1` - `PR gate workflow: validate the bump intent and run the suites`, and removing the notice from any `SKILL.md` is epic 2.

### Before you start

The rendering contract for the notice is in the header of `claude/tools/partials/read-only-notice.md.tmpl`, and part one deliberately did not implement it - you are the first renderer. Three steps: discard every line through the first blank line, substitute `%%SKILL_NAME%%` with the skill's directory name, emit the rest byte for byte with one trailing newline. Step 1 exists so the version marker satisfies `read_tool_version` without reaching the output, which has to match six specific lines exactly.

**The notice names `skill-sync.sh` hardcoded, twice. It is not a placeholder and must not become one.** That was a decision recorded on `WO-20260824-2136` - `Extract the read-only notice into a single rendered partial`, not an oversight.

Then decide the fixture shape for the ownership matrix before writing the swap, for the same reason part one wrote its fixtures before its parser.

### Read in this order

1. Root `CLAUDE.md`. Rules 12, 14, 15 and 17 all bear on this one.
2. This entry, the top entry of `HYDRATION.md`. Read only this one.
3. `claude/tools/skill-sync.sh`, all of it. You are extending a file, not writing one, and its header states what it deliberately does not do.
4. `claude/tools/testing/run-tests.sh`, which is the suite you are adding to rather than replacing. Its fixture helpers - `mkproject`, `mkregistry`, `mkreceipt`, `mkstub`, `run_sync`, `plan_has`, `snapshot` - are the ones your cases want.
5. The ticket: `work-orders/WO-20260824-f1a5/WO-20260824-efb0-skill-sync-sh-part-two-build-swap-receipt-and-se.md`.
6. `docs/superpowers/specs/2026-08-23-skills-package-manager-design.md`, sections `Flows` -> `Session sync` and `Self-update`, `Failure modes` including `mv, never cp`, and `Ownership is per-directory, not per-parent`.
7. `docs/superpowers/plans/2026-08-24-skills-package-manager-implementation.md` section `E1.6` below the rule, and `What skill-sync.sh's suite must cover`, which is the ownership matrix in table form.
8. `claude/tools/partials/read-only-notice.md.tmpl`, header included.

### Reuse, it is proven

`claude/tools/testing/run-tests.sh` already re-execs into Podman, stubs `curl` on `PATH` with a call counter, and hashes the project tree before and after. Extend it; do not stand up a second suite.

`snapshot()` in that file is the "nothing was touched" assertion `AC-H1` needs, and it is already there. Point it at a hand-authored skill directory instead of the project root.

`mkstub` takes a mode - `fail`, `empty`, `flaky`, `ok`, `real`. Add modes rather than writing a second stub.

`claude/skills/work-order/scripts/lib/common.sh` emits JSON from hand-rolled bash and is the precedent for writing the receipt without `jq`. `json_array` and `json_string` in `skill-sync.sh` are the matching readers, and the receipt you write has to be one the readers already there can read back.

### The verification ladder

Rung 1, free: `grep -c 'SKILL_SYNC_CHILD' claude/tools/skill-sync.sh` is non-zero, and the `mv`-not-`cp` comment is present. That is `AC-H4`, and it is the one criterion a grep settles.

Rung 2: the ownership matrix, all four rows. The last row - **not in the manifest, not in the receipt** - is the one that matters: assert the directory is untouched _and never even read_. A wrong answer there silently deletes hand-authored work in a gitignored directory, with no diff and nothing to notice it by. That is `AC-H1`.

Rung 3: a missing receipt collapses to "sync owns nothing" and deletes nothing; a corrupt one does the same rather than throwing. That is `AC-H2`'s second half.

Rung 4: exit 0 on every failure path, with the loud print, still asserted separately. That is `AC-H3`, and part one's `AC-H3` group is the shape to copy.

Rung 5: a hard kill during the build leaves every owned directory at its previous version and none half-written. Then the sweep: plant a `.sync.` directory with an old mtime, assert it is gone; plant a fresh one, assert it survives.

Rung 6: two concurrent syncs, one waits, neither corrupts the tree. Per `skill-testing.md`, a script that claims a lock has that claim tested.

Rung 7: `skill-version.sh init` then `verify` rc 0, with the regenerated `registry.json` committed - `skill-sync.sh`'s hash moved.

Rung 8: `bash claude/tools/testing/run-tests.sh`, plus `skill-versioning` still at 103 and repo-local `tools/` still at 36.

### Traps, already paid for

`cp script script.bak && curl -o script` truncates the live inode. Bash reads a script lazily by byte offset, so the running shell then reads garbage from wherever it had reached, and it fails in ways that look like anything except a self-update bug. `mv` is a rename: the inode survives. The spec says this and the comment saying it is `AC-H4`.

A suite written with `set -euo pipefail` dies on its first intentionally-failing check and reports the assertion passing as an error. Every suite in this repository uses `set -uo pipefail` and says why.

A `grep -q` in a pipeline reports "no match" when it matched: `grep -q` closes the pipe on the first hit, the upstream dies of SIGPIPE, and `pipefail` turns that into a non-zero pipeline. Capture to a variable and grep the variable.

A grep over the source for `flock`, `cmp` or `diff` matches the comment saying the script uses none of them. Part one's Rule 17 group strips comments first; reuse it rather than rediscovering why it fails.

Minimal images ship neither `cmp` nor `diff`. `claude/tools/testing/Containerfile` installs bash and nothing else on purpose, and `curl` is absent so the stub is provably the only one on `PATH`. Adding a package to make a case easier removes an assertion.

`flock` does not exist on Git Bash. Lock with `mkdir`. Its absence surfaces as a lock timeout that never happened, which is the worst possible error message.

A markdown formatter re-pads tables in a file you only meant to add one line to. It is a `PostToolUse` hook in the machine's global `~/.claude/settings.json`, not in this repository. `git diff --stat` before committing; a two-line change reporting forty is this.

`work-order.sh start` refuses with "working tree is dirty", and `git rebase` refuses immediately after `start` because `start` leaves the ticket file, `INDEX.md` and the epic README uncommitted. Commit them first.

A command reports success and did nothing. A prompt with no TTY takes its default and exits 0. Assert the post-state, never `$?` alone.

### Workflow

```bash
WO=claude/skills/work-order/scripts/work-order.sh
HP=claude/skills/hydration-prompt/scripts/hydration.sh
SV=claude/skills/skill-versioning/scripts/skill-version.sh

bash $WO show    --project . --id WO-20260824-efb0
bash $WO start   --project . --id WO-20260824-efb0   # creates the branch, leaves files uncommitted

# ... extend skill-sync.sh and its suite, prove it in Podman ...

bash $SV init                                        # skill-sync.sh's hash moved; no skill bump is owed
bash $SV verify                                      # this one has to be green

bash $WO evidence --project . --id WO-20260824-efb0 --index 1 --observed "..."
bash $WO evidence --project . --id WO-20260824-efb0 --index 2 --observed "..."
bash $WO evidence --project . --id WO-20260824-efb0 --index 3 --observed "..."
bash $WO evidence --project . --id WO-20260824-efb0 --index 4 --observed "..."

git push -u origin <branch>
gh pr create --base main --title "..." --body-file <file>

bash $WO submit  --project . --id WO-20260824-efb0 --pr <N>
bash $WO done    --project . --id WO-20260824-efb0   # archives on the branch, commits nothing

bash $HP check   --project . --body-file /tmp/entry.md
bash $HP add     --project . --id <next> --title "<next title>" --body-file /tmp/entry.md

git add -A && git commit && git push                 # rides the SAME pull request

# after the merge
bash $WO cleanup --project . --id WO-20260824-efb0   # deletes both branches, writes nothing
```

`approve` is already done for every ticket in both epics and must not be run again.

The pull request description is the merge commit body verbatim. Write it as something worth reading on `main`, because that is where it ends up.

### Conventions

Every reference to a work-order in a chat reply carries the ticket ID and its full title joined by a dash. A bare ID is a defect, and so is "the next ticket" or "the blocked one".

Feature branches only, and nothing writes to `main` any more.

Rule 14 has no size threshold. A single `--help` run whose purpose is to check that something works goes in a container.

When the ticket contradicts itself, say so and pick one in the open. Part one did, twice - the sweep box and the `justfile` clause - and both are recorded as notes on the ticket rather than smoothed over.

<!-- hydration-entry: WO-20260824-5b89 -->
## WO-20260824-5b89 - skill-sync.sh part one: resolution, and the tools test tree it is proved in
_Generated 2026-08-24 by hydration.sh. Newest entry._

### Ticket

`WO-20260824-5b89` - `skill-sync.sh part one: resolution, and the tools test tree it is proved in`.
Both of its dependencies are now `done`: `WO-20260824-de9e` - `Registry schema 2, with type derived from the tree and requires read from frontmatter`, and `WO-20260824-2136` - `Extract the read-only notice into a single rendered partial`, which merged as PR #63.
`work-order next` returns it first.

It blocks `WO-20260824-efb0` - `skill-sync.sh part two: build, swap, receipt, and self-update`, which is the other half of the same script.

Poker put it at 5 points, split out of a 13. The seam is deliberate: resolution is a pure function of its inputs and can be tested without anything destructive happening, and standing up `claude/tools/testing/` belongs here so that part two is never the ticket where part one first gets tested.

### What just landed

`claude/tools/` exists. It has exactly one file in it: `claude/tools/partials/read-only-notice.md.tmpl`, at version `1.0.0`, and a matching `read-only-notice` entry in the `tools` block of `claude/skills/registry.json` with a version and a `sha256`.

The template carries the rendering contract in its own header, because the renderer that has to honour it is **your ticket** and a convention living anywhere else would not survive the trip:

1. discard every line through the first blank line - that is the header
2. substitute `%%SKILL_NAME%%` with the skill's directory name
3. emit the rest byte for byte, one trailing newline, nothing else

Step 1 exists because `render_tools` requires a `skill-tool-version:` marker in the file's first 20 lines, while the rendered output has to reproduce six specific lines exactly. A stripped header satisfies both without a rule that inspects the body.

**The notice names `skill-sync.sh`, hardcoded, twice.** It is not a placeholder and must not become one. That was a decision, not an oversight: the ticket's `AC-H1` asked for output byte-identical to `claude/skills/work-order/SKILL.md` lines 9-14, and those lines say `skill-update.sh`, while the same ticket's non-goals and the design spec both say `skill-sync.sh`. Both could not hold. The rendered output is identical to those six lines with the two occurrences renamed and nothing else changed, and the ticket's evidence says exactly that rather than claiming the criterion was met as written.

Before that: `WO-20260824-7a63` - `Close-out moves onto the branch: done archives, cleanup only deletes branches` moved the whole close-out onto the feature branch, and `WO-20260824-de9e` - `Registry schema 2, with type derived from the tree and requires read from frontmatter` gave every registry entry a derived `type` and a `requires`.

Suites at the moment you start: `skill-versioning` 103, `work-order` 299 across 22 case files, repo-local `tools/` 36. All green in Podman on digest-pinned bases with `--network=none`.

### What is NOT done

`claude/tools/skill-sync.sh` does not exist, and neither does `claude/tools/testing/`. **Both are your ticket.**

- `ls claude/tools` prints `partials` and nothing else.
- `grep '"skill-sync"' claude/skills/registry.json` prints nothing. `skill-sync` is already in `TOOLS_REGISTERED` in `skill-version.sh`, so its entry appears on its own the moment the file lands with a marker in it. There is no table to extend.
- `git ls-files .github/workflows` prints nothing. No PR gate, no publisher.
- `grep -l "This copy is read-only" claude/skills/*/SKILL.md | wc -l` prints `43`. The notice has left none of them - that is epic 2, and explicitly not this ticket.
- No `.claude/skills.toml` exists anywhere in this repository. You are writing the parser before the first manifest exists, so your fixtures are the only manifests there are.

Nothing was carried off `WO-20260824-2136` - `Extract the read-only notice into a single rendered partial`. Both acceptance criteria were evidenced, `AC-H1` with its deviation recorded in the evidence text and in a note on the ticket.

Branch protection is still absent and still on no ticket.

### Stale or false in the docs

`docs/superpowers/plans/2026-08-24-skills-package-manager-implementation.md` section `E1.6 - claude/tools/skill-sync.sh` is the checklist for **both** halves of the script. The first five boxes plus the `--boot` box are yours; everything from `Build into .claude/cache/.sync.XXXXXX` down belongs to `WO-20260824-efb0` - `skill-sync.sh part two: build, swap, receipt, and self-update`. The plan predates the split and does not mark the seam.

Both design documents still state the repository settings as `squash_merge_commit_message=COMMIT_MESSAGES`, `allow_merge_commit=true`, `allow_rebase_merge=true` - at `C2` in the plan and under `Repo settings, first` in the spec. All three were changed by `WO-20260824-cc71` - `Repo settings: squash-only, with the commit body taken from the PR description`.

Both also still carry the `SessionStart` matcher question as open, at `C7` and `E1.2` in the plan and under `Problem A` in the spec. It was answered by `WO-20260824-0615` - `Confirm whether a SessionStart hook matcher filters by source`: matchers do filter by source, alternation is honoured, the stdin-read fallback is dead. It bears on the hook, which is `WO-20260824-bb0d` - `setup.sh installs the skill-sync binary, then the SessionStart hook`, not on you.

Root `CLAUDE.md` Rule 16 requires a PR touching a skill to bump that skill and ship a regenerated `registry.json`. **It does not bind this ticket**: `claude/tools/` is not under `claude/skills/`, so nothing you write here owes a skill bump. Adding `skill-sync.sh` does change `registry.json`, which must be regenerated with `skill-version.sh init` in the same commit or plain `verify` goes red.

`workflows/close-out-procedure.md`, `claude/skills/work-order/SKILL.md` and root `CLAUDE.md` are all current on the close-out. `claude/skills/skill-versioning/SKILL.md` is current on schema 2.

### Your scope

Two things, and the test tree is half the ticket.

**`claude/tools/skill-sync.sh`, resolution only.** Everything it needs to decide what should be installed, and nothing that installs it:

- `--boot`: no `.claude/skills.toml` in this directory, or a stamp under 15 minutes old, exits 0 and prints nothing at all. Not a quiet message - nothing.
- A minimal hand-rolled manifest parse. No TOML parser exists on Git Bash and Rule 17 says Windows is supported, so this reads `[skills] use = [...]` and `[agents] use = [...]` with the tools that are actually there. The format is under `Data formats` -> `Manifest` in the spec.
- Registry fetch, three attempts, then a loud two-line failure and **exit 0**. A sync that fails must never fail the session it was hooked into.
- Resolve `requires` transitively into the owned set. The two real edges are both on `work-order`, from `cartography` and `living-docs`.
- Read the receipt at its documented path for the previously owned set. The shape is under `Receipt` in the spec.

**`claude/tools/testing/run-tests.sh` and its `Containerfile`**, on the debian digest the existing suites already pin.

Out, and named because they are the obvious next thoughts: writing anything into `.claude/skills/`, the temp build, the directory swap, the receipt write, and the self-update path - all four are `WO-20260824-efb0` - `skill-sync.sh part two: build, swap, receipt, and self-update`. Also out: removing the notice from any `SKILL.md`, which is epic 2, and any `.github/workflows/` file.

### Before you start

Decide where the receipt and the stamp live, and write both paths into `skill-sync.sh` as constants even though part one only reads them. Part two writes them, and two tickets inventing the same path independently is how they end up disagreeing.

Then decide what your fixtures look like before you write the parser. The resolution half has no output anyone can look at - it is a set - so the suite is the only place its correctness is visible, and a fixture tree invented while chasing a failing assertion tends to encode the bug.

### Read in this order

1. `workflows/close-out-procedure.md`. Short, has a diagram, and is the thing that changed most recently.
2. Root `CLAUDE.md`. Rules 12, 14, 15 and 17 all bear on this one - Rule 17 hardest, because this script is the first thing in the repository that has to run under Git Bash.
3. This entry, the top entry of `HYDRATION.md`. Read only this one.
4. The ticket: `work-orders/WO-20260824-f1a5/WO-20260824-5b89-skill-sync-sh-part-one-resolution-and-the-tools-.md`, including both of its notes.
5. `docs/superpowers/specs/2026-08-23-skills-package-manager-design.md`, sections `Data formats` (manifest, registry schema 2, receipt), `Flows` -> `Session sync`, and `Failure modes`.
6. `docs/superpowers/plans/2026-08-24-skills-package-manager-implementation.md` section `E1.6`, remembering it covers both halves.
7. `claude/tools/partials/read-only-notice.md.tmpl`, header included. You do not render it in this ticket, but you are the one who has to keep the contract implementable.

### Reuse, it is proven

`tools/testing/run-tests.sh` is the closest worked example of the suite you have to stand up. It re-execs itself into Podman rather than expecting the caller to remember the `podman run` line, mounts the repo read-only, runs `--network=none`, and builds its own image from a sibling `Containerfile`. Copy the shape.

`claude/skills/skill-versioning/testing/run-tests.sh` is the larger example at 103 checks, and its section 6b builds a fixture tools tree at `$WORK/tools` and proves the populated registry path against it - it needs neither git nor a network, which is exactly your constraint.

`read_tool_version` in `claude/skills/skill-versioning/scripts/skill-version.sh` is the marker reader. `skill-sync.sh` needs its own `# skill-tool-version: 1.0.0` in the first 20 lines or `render_tools` kills every `skill-version.sh` subcommand at once.

`claude/skills/work-order/scripts/lib/common.sh` emits JSON from hand-rolled bash and is the precedent for doing so without `jq`.

### The verification ladder

Rung 1, free: `head -20 claude/tools/skill-sync.sh` shows the marker.

Rung 2: `--boot` in a directory with no manifest produces empty stdout **and** empty stderr, and exits 0. That is `AC-H2`, and asserting the exit code alone does not prove it.

Rung 3: the owned set against a manifest fixture, a registry fixture and a receipt fixture, with a transitive `requires` in the graph. That is `AC-H1`.

Rung 4: three failed fetches produce the two-line failure and still exit 0. That is `AC-H3`. Stub the fetch; `--network=none` means an unreachable registry is the default state, not something you have to arrange.

Rung 5: `skill-version.sh init` then `grep '"skill-sync"' claude/skills/registry.json` shows the entry, and `skill-version.sh verify` exits 0 with the regenerated registry committed.

Rung 6: `bash claude/tools/testing/run-tests.sh`, plus `bash claude/skills/skill-versioning/testing/run-tests.sh` still at 103.

### Traps, already paid for

`skill-sync.sh` lands without a `skill-tool-version:` marker and every `skill-version.sh` subcommand dies at once, inside `render_registry`, so `init`, `bump` and `verify` all fail together. `render_tools` treats a registered tool present without a version as a hard failure on purpose.

A suite written with `set -euo pipefail` dies on its first intentionally-failing check and reports the assertion passing as an error. Every suite in this repository uses `set -uo pipefail` and says why.

A `grep -q` in a pipeline reports "no match" when it matched: `grep -q` closes the pipe on the first hit, the upstream command dies of SIGPIPE, and `pipefail` turns that into a non-zero pipeline. Capture to a variable and grep the variable.

Minimal images ship neither `cmp` nor `diff`. The `bitnami/git` digest the skill suites use has no `diff`. Check for a utility before depending on it, or compare with a shell string test.

`flock` does not exist on Git Bash. Lock with `mkdir`, which is atomic everywhere. Its absence surfaces as a lock timeout that never happened, which is the worst possible error message.

A markdown formatter re-pads tables in a file you only meant to add one line to. It is a `PostToolUse` hook in the machine's global `~/.claude/settings.json`, not in this repository. `git diff --stat` before committing; a two-line change reporting forty is this.

`work-order.sh start` refuses with "working tree is dirty", and `git rebase` refuses immediately after `start` because `start` leaves the ticket file, `INDEX.md` and the epic README uncommitted. Commit them first.

A command reports success and did nothing. A prompt with no TTY takes its default and exits 0. Assert the post-state, never `$?` alone.

### Workflow

```bash
WO=claude/skills/work-order/scripts/work-order.sh
HP=claude/skills/hydration-prompt/scripts/hydration.sh
SV=claude/skills/skill-versioning/scripts/skill-version.sh

bash $WO show    --project . --id WO-20260824-5b89
bash $WO start   --project . --id WO-20260824-5b89   # creates the branch, leaves files uncommitted

# ... write skill-sync.sh and claude/tools/testing/, prove it in Podman ...

bash $SV init                                        # regenerates registry.json; no skill bump is owed
bash $SV verify                                      # this one has to be green

bash $WO evidence --project . --id WO-20260824-5b89 --index 1 --observed "..."
bash $WO evidence --project . --id WO-20260824-5b89 --index 2 --observed "..."
bash $WO evidence --project . --id WO-20260824-5b89 --index 3 --observed "..."

git push -u origin <branch>
gh pr create --base main --title "..." --body-file <file>

bash $WO submit  --project . --id WO-20260824-5b89 --pr <N>
bash $WO done    --project . --id WO-20260824-5b89   # archives on the branch, commits nothing

bash $HP check   --project . --body-file /tmp/entry.md
bash $HP add     --project . --id <next> --title "<next title>" --body-file /tmp/entry.md

git add -A && git commit && git push                 # rides the SAME pull request

# after the merge
bash $WO cleanup --project . --id WO-20260824-5b89   # deletes both branches, writes nothing
```

`approve` is already done for every ticket in both epics and must not be run again.

The pull request description is the merge commit body verbatim. Write it as something worth reading on `main`, because that is where it ends up.

### Conventions

Every reference to a work-order in a chat reply carries the ticket ID and its full title joined by a dash. A bare ID is a defect, and so is "the next ticket" or "the blocked one".

Feature branches only, and nothing writes to `main` any more.

Rule 14 has no size threshold. A single `--help` run whose purpose is to check that something works goes in a container.

When the ticket contradicts itself, say so and pick one in the open. The last ticket did, and the deviation is recorded in three places rather than smoothed over in none.

<!-- hydration-entry: WO-20260824-2136 -->
## WO-20260824-2136 - Extract the read-only notice into a single rendered partial
_Generated 2026-08-24 by hydration.sh. Newest entry._

### Ticket

`WO-20260824-2136` - `Extract the read-only notice into a single rendered partial`. Still the only startable child of `WO-20260824-f1a5` - `Skills package manager: prove the path on one skill`, and `work-order next` returns it.

**This entry supersedes the earlier one for the same ticket.** That one is still in this file, two entries down, and its `Workflow` block is wrong: the close-out procedure changed underneath it. Read this one and ignore that one entirely.

Two things merged since it was written: `WO-20260824-de9e` - `Registry schema 2, with type derived from the tree and requires read from frontmatter`, and `WO-20260824-7a63` - `Close-out moves onto the branch: done archives, cleanup only deletes branches`. The second is why you are reading a second entry.

It unblocks `WO-20260824-5b89` - `skill-sync.sh part one: resolution, and the tools test tree it is proved in`, which is the last edge holding that ticket shut.

### What just landed

**The close-out procedure changed, and it is the thing most likely to trip you.** `workflows/close-out-procedure.md` is the full version with a diagram. The short form:

```
submit --pr N  ->  done  ->  hydration entry  ->  commit  ->  push  ->  merge  ->  cleanup
                    ^                                                              ^
       archives, commits nothing                          deletes branches, writes nothing
```

`done` is now the whole close-out. It stamps `status` and `closed`, moves the ticket to `work-orders/archive/<year>/`, prunes an emptied epic directory, regenerates `INDEX.md` and the epic READMEs, and commits none of it. You commit that move with the hydration entry, onto the same pull request.

`close` no longer exists. It is `cleanup`, it runs after the merge, it deletes the local and remote branch, and it writes nothing at all. It still refuses unless `gh` reports the pull request `MERGED`, because that assertion now guards an actual delete.

There is no `merge_sha`. A commit cannot contain its own merge SHA, and storing it was the only reason close-out ever needed a second act. `pr` is the pointer, and `gh pr view <n> --json mergeCommit` resolves it forever.

A repo-local `tools/` tree now exists at the repository root, with its own `CLAUDE.md`. It is for tooling that maintains this repository and is never vendored. `claude/tools/` is the distributed one. `render_tools` only ever walks `claude/tools/`, so nothing at the root can reach the registry.

`tools/workflow-version.sh` at 1.0.0 owns the versions of the documents in `workflows/`. It has no index on purpose - nothing fetches those documents, so a generated file would have no reader.

Before that, schema 2 landed. Every registry entry carries a derived `type` and a `requires`, `verify` reports an unresolved `requires:` and a schema mismatch as their own failures rather than as drift, and the `tools` block renders `{}` until `claude/tools/` exists.

Suites: 299 checks across 22 case files for `work-order`, 36 for `tools/`, 103 for `skill-versioning`. All green in Podman on digests pinned per Rule 15 with `--network=none`.

### What is NOT done

`claude/tools/` still does not exist. **That is your ticket** - the partial is the first file in it.

- `ls claude/tools` fails. No `skill-sync.sh`, no partial, no `claude/tools/testing/`.
- `git ls-files .github/workflows` prints nothing. No PR gate, no publisher, so nothing calls `verify --structure` and nothing reads a `Bump:` trailer.
- `grep -l "This copy is read-only" claude/skills/*/SKILL.md | wc -l` prints `43`. Removing the notice is the pilot and epic 2, and is explicitly out of scope here.
- `grep -c '"tools": {}' claude/skills/registry.json` prints `1`. The block is real and empty.

Nothing was carried off `WO-20260824-7a63` - `Close-out moves onto the branch: done archives, cleanup only deletes branches`. All four acceptance criteria were met and evidenced separately.

Branch protection is still absent and still on no ticket. It matters less than it did: no command writes to `main` any more, so nothing depends on that push being allowed.

### Stale or false in the docs

**The earlier `HYDRATION.md` entry for this same ticket is wrong about close-out.** Its `Workflow` block calls `close`, and its `Traps` section describes a `close` refusal that can no longer happen. `HYDRATION.md` is append-only and never edited in place, so it is still sitting there. This entry is the correction.

`docs/superpowers/plans/2026-08-24-skills-package-manager-implementation.md` and `docs/superpowers/specs/2026-08-23-skills-package-manager-design.md` both still state the repository settings as `squash_merge_commit_message=COMMIT_MESSAGES`, `allow_merge_commit=true`, `allow_rebase_merge=true`, at `C2` in the plan and under `Repo settings, first` in the spec. All three were changed by `WO-20260824-cc71` - `Repo settings: squash-only, with the commit body taken from the PR description`.

Both also still carry the `SessionStart` matcher question as open, at `C7` and `E1.2` in the plan and under `Problem A` in the spec. It was answered by `WO-20260824-0615` - `Confirm whether a SessionStart hook matcher filters by source`: matchers do filter by source, alternation is honoured, the stdin-read fallback is dead.

Neither is this ticket's business. `WO-20260824-bb0d` - `setup.sh installs the skill-sync binary, then the SessionStart hook` and `WO-20260824-8cd1` - `Rewrite root CLAUDE.md for merge-time allocation and the named main exception` each own their half.

Root `CLAUDE.md` Rule 16 still requires a PR touching a skill to bump the version and ship a regenerated `registry.json` by hand. **It does not bind this ticket**: `claude/tools/` is not under `claude/skills/`, so a PR that only adds the template touches no skill and owes no bump. Adding the template does change `registry.json`, which must be regenerated with `skill-version.sh init` in the same commit or plain `verify` goes red.

`claude/skills/work-order/SKILL.md` and root `CLAUDE.md` are both current on the new close-out. `claude/skills/skill-versioning/SKILL.md` is current on schema 2 and gives its check count as 103.

### Your scope

One file and one registry entry: `claude/tools/partials/read-only-notice.md.tmpl`, and the `read-only-notice` entry it causes `render_tools` to emit.

The template holds the six-line notice with the skill's own name substituted in one place. Its rendered output must be byte-identical to `claude/skills/work-order/SKILL.md` lines 9 to 14 as they stand today. Byte-identical is the acceptance criterion because it is the only way to prove this is a refactor and not a rewrite.

The tool name inside the notice is hardcoded to `skill-sync.sh` and is **not** a placeholder. After this work `skill-update.sh` no longer installs synced skills, so a rendered copy naming it would be wrong.

**The template must carry a version marker in its first 20 lines**, because `render_tools` reads one:

```
<!-- skill-tool-version: 1.0.0 -->
```

`read_tool_version` in `claude/skills/skill-versioning/scripts/skill-version.sh` is the reader. `tools/workflow-version.sh` uses the same token shape against `workflows/`, and is worth reading as a second worked example.

Out of scope, and named because they are the obvious next thoughts: removing the notice from any `SKILL.md`, which is the pilot and epic 2; making the tool name a placeholder; writing the renderer, which belongs to `skill-sync.sh`; and creating `claude/tools/testing/`, which stays with `WO-20260824-5b89` - `skill-sync.sh part one: resolution, and the tools test tree it is proved in`.

### Before you start

Settle how the version marker survives the byte-identical requirement. It is the one thing the ticket text does not anticipate, because the marker convention was introduced after the ticket was written.

The marker must be inside the template's first 20 lines for `render_tools` to find it, and it must not appear in the rendered output, which has to match six specific lines exactly. So something has to strip it. Decide between a template whose first line is the marker and a renderer that drops a leading `<!-- skill-tool-version: -->` line, and a template that stores the marker somewhere the substitution step naturally discards.

Write the rule into the template itself. The renderer that has to honour it does not exist yet - it is `WO-20260824-5b89` - `skill-sync.sh part one: resolution, and the tools test tree it is proved in` and the one after it - and a convention living only in this entry will not survive to meet it.

### Read in this order

1. `workflows/close-out-procedure.md`. It is short, it has a diagram, and it is the thing that changed most recently.
2. Root `CLAUDE.md`. Rules 12, 14, 15 and 17 bear on this work. Rule 16 does not, because `claude/tools/` is not under `claude/skills/`. There is no `CONTEXT_STATE.md` in this repository.
3. This entry, the top entry of `HYDRATION.md`. Read only this one - the older entry for this same ticket is superseded.
4. The note on the epic `WO-20260824-f1a5` - `Skills package manager: prove the path on one skill`, newest first. It records why the `tools` block ships empty.
5. `docs/superpowers/specs/2026-08-23-skills-package-manager-design.md`, the section `The read-only notice becomes a partial`. It quotes the six lines.
6. The ticket file: `work-orders/WO-20260824-f1a5/WO-20260824-2136-extract-the-read-only-notice-into-a-single-rende.md`.
7. `claude/skills/work-order/SKILL.md` lines 9 to 14, the bytes you have to reproduce.
8. `claude/skills/skill-versioning/scripts/skill-version.sh`, `render_tools` and `read_tool_version` together.

### Reuse, it is proven

`render_tools` already does the whole registry side. Drop the file at `claude/tools/partials/read-only-notice.md.tmpl` with a marker in it and the entry appears on its own - `read-only-notice` is already in `TOOLS_REGISTERED`, so there is no table to extend and no edit to make in `skill-version.sh`.

`tools/workflow-version.sh` is the closest worked example of the marker convention: same token shape, its own reader, its own suite. `tools/testing/run-tests.sh` is the closest example of a suite for a tool that is not a skill, and it re-execs itself into the container rather than expecting the caller to remember the `podman run` line.

`claude/skills/skill-versioning/testing/run-tests.sh` section 6b builds a fixture tools tree at `$WORK/tools` and proves the populated path against it. Copy that if this ticket wants its own assertions - it needs neither git nor a network.

`claude/skills/work-order/scripts/work-order.sh` owns every ticket transition. Never hand-edit a ticket file. `note` is the only way a note reaches a ticket, `evidence` the only way a criterion gets ticked.

`claude/skills/hydration-prompt/scripts/hydration.sh` owns `HYDRATION.md`. Run `check --body-file` before `add`; `add` refuses a body that fails `check`.

`gh` is authenticated and works here. `gh-axi` wraps it and is preferred where it fits.

### The verification ladder

Rung 1, free: `head -20 claude/tools/partials/read-only-notice.md.tmpl` shows the marker. Without it `render_tools` dies, and it dies inside `render_registry`, so `init`, `bump` and `verify` all fail at once.

Rung 2, cheap: substitute the skill name by hand in a container and compare against `claude/skills/work-order/SKILL.md` lines 9 to 14. That is `AC-H1`. Minimal images ship neither `cmp` nor `diff`, so check before depending on either or compare with a shell string test.

Rung 3: `skill-version.sh init`, then `grep '"read-only-notice"' claude/skills/registry.json` shows the entry with a version and a `sha256`. That is `AC-H2`.

Rung 4: `skill-version.sh verify` exits 0 on the branch. The template is new, so the registry moves, and the run is green only if the regenerated registry is committed with it.

Rung 5: `bash claude/skills/skill-versioning/testing/run-tests.sh` in Podman, all 103 checks still green.

### Traps, already paid for

The template exists but carries no marker, and every `skill-version.sh` subcommand dies at once. `render_tools` treats a registered tool present without a `skill-tool-version:` as a hard failure on purpose - an entry with no version is one no consumer can compare.

`render_registry` no longer reproduces the file byte for byte and every skill reads as drifted. A trailing newline, a key order change or a space after a colon does it. Compare rendered output to the file before touching any test.

A suite written with `set -euo pipefail` dies on its first intentionally-failing check and reports the assertion passing as an error. Both suites in this repository use `set -uo pipefail` for that reason and say so.

A `grep -q` in a pipeline reports "no match" when it matched. `grep -q` closes the pipe on the first hit, the upstream command dies of SIGPIPE, and `pipefail` turns that into a non-zero pipeline. Capture to a variable and grep the variable.

A markdown formatter re-pads tables in a file you only meant to add one line to. It is a `PostToolUse` hook in the machine's global `~/.claude/settings.json`, not in this repository, so the churn is local and does not belong in a diff. `git diff --stat` before committing; a two-line change reporting forty is this. `git checkout HEAD -- <file>` and re-apply with `sed`, which does not trip the hook.

`work-order.sh start` refuses with "working tree is dirty". `new` and `approve` both write files, so a ticket cut in the same session leaves the tree dirty on `main` and `start` will not cut a branch from it. Carry the change onto a scratch branch, commit it there, then run `start` from that clean tree - it cuts `feat/<slug>` from wherever HEAD is.

`git rebase` refuses with "cannot rebase: You have unstaged changes" immediately after `start`. `start` writes the ticket file, `INDEX.md` and the epic README and leaves them uncommitted. Commit them before rebasing.

A command reports success and did nothing. A prompt with no TTY takes its default and exits 0. Assert the post-state, never `$?` alone.

### Workflow

```bash
WO=claude/skills/work-order/scripts/work-order.sh
HP=claude/skills/hydration-prompt/scripts/hydration.sh
SV=claude/skills/skill-versioning/scripts/skill-version.sh

bash $WO show    --project . --id WO-20260824-2136
bash $WO start   --project . --id WO-20260824-2136   # creates the branch, leaves files uncommitted

# ... write the template, in a container ...

bash $SV init                                        # regenerates registry.json; no bump is owed
bash $SV verify                                      # this one has to be green

bash $WO evidence --project . --id WO-20260824-2136 --index 1 --observed "..."
bash $WO evidence --project . --id WO-20260824-2136 --index 2 --observed "..."

git push -u origin <branch>
gh pr create --base main --title "..." --body-file <file>

bash $WO submit  --project . --id WO-20260824-2136 --pr <N>
bash $WO done    --project . --id WO-20260824-2136   # archives on the branch, commits nothing

bash $HP check   --project . --body-file /tmp/entry.md
bash $HP add     --project . --id <next> --title "<next title>" --body-file /tmp/entry.md

git add -A && git commit && git push                 # rides the SAME pull request

# after the merge
bash $WO cleanup --project . --id WO-20260824-2136   # deletes both branches, writes nothing
```

`approve` is already done for every ticket in both epics and must not be run again.

The pull request description is the merge commit body verbatim. Write it as something worth reading on `main`, because that is where it ends up.

### Conventions

Every reference to a work-order in a chat reply carries the ticket ID and its full title joined by a dash. A bare ID is a defect, and so is "the next ticket" or "the blocked one".

Feature branches only, and `main` is now never written by anything. The old exception was `work-order close` committing its archive directly; that command writes nothing any more.

Rule 14 has no size threshold. A single `--help` run whose purpose is to check that something works goes in a container.

<!-- hydration-entry: WO-20260824-2136 -->
## WO-20260824-2136 - Extract the read-only notice into a single rendered partial
_Generated 2026-08-24 by hydration.sh. Newest entry._

### Ticket

`WO-20260824-2136` - `Extract the read-only notice into a single rendered partial`. It is the only startable child of the epic - `work-order next` returns it and nothing else from `WO-20260824-f1a5` - `Skills package manager: prove the path on one skill`.
Predecessor `WO-20260824-de9e` - `Registry schema 2, with type derived from the tree and requires read from frontmatter`, merged as PR #60, closed and archived.

Poker put it at 2 points and called it the anchor: one template file, one byte-identical acceptance criterion, no unknowns. That was true when it was written and it is one item less true now - see `Before you start`.

It unblocks `WO-20260824-5b89` - `skill-sync.sh part one: resolution, and the tools test tree it is proved in`, which depends on this ticket and on the predecessor. The predecessor is done, so this is the last edge holding `5b89` shut.

### What just landed

The registry is schema 2.

```json
"living-docs": { "version": "1.0.1", "sha256": "100d0484…", "type": "skill", "requires": ["work-order"] }
```

Still one entry per line. That line is what `verify` compares and what it prints when a skill drifts, so nothing may split an entry across lines.

`type` is derived from the tree an entry was found in and is never declared. The walk covers the skills tree only, so all 43 entries render as `skill`. `claude/agents/` still carries no version and no registry row.

`requires` is an optional frontmatter key, comma-separated, read with one line of `awk` from the leading fenced block only. `requires: work-order` is on `living-docs` and `cartography` and on nothing else - 2 of 43 entries carry a non-empty array, the other 41 render `[]`.

`verify` gained two failures that are distinct from drift:

```
unresolved requires   living-docs -> work-ordr (no such skill)
schema mismatch: registry is schema 1, this generator writes schema 2
```

Both forms assert the first, because an unresolved `requires:` is a property of the tree rather than of the registry. The second refuses to run the comparison at all, because a cross-schema comparison differs on every line and would name all 43 skills as drifted while explaining none of them.

**The `tools` block ships empty, and that was a deliberate decision, not an oversight.** `render_tools` emits an entry only for a registered tool that exists on disk. `claude/tools/` does not exist, so it renders `"tools": {}`. The reasoning is a note on the epic `WO-20260824-f1a5` - `Skills package manager: prove the path on one skill` and it is the anchor to point a later session at.

The suite is at 103 checks, 42 negative, green in Podman on `bitnami/git` pinned by digest with `--network=none`. Sections 6, 6b and 6c are new and need neither git nor a network.

Bumps that rode the PR: `skill-versioning` 1.2.0 to 2.0.0, major because the format of `registry.json` changed; `living-docs` to 1.0.1 and `cartography` to 1.0.3, both patch for one frontmatter key.

### What is NOT done

Nothing has been built in either epic outside `claude/skills/skill-versioning/`. Seventeen of the twenty-one tickets have never been started and none of them has a branch.

Each of these is a command whose output proves the claim, measured on `main` after PR #60 merged:

- `ls claude/tools` fails. No `skill-sync.sh`, no partial, no tools test suite. **The partial is your ticket.**
- `git ls-files .github/workflows` prints nothing. No PR gate, no publisher, so nothing yet calls `verify --structure` and nothing yet reads a `Bump:` trailer.
- `grep -l "This copy is read-only" claude/skills/*/SKILL.md | wc -l` prints `43`. Every skill still carries the inline notice. Removing it is the pilot and epic 2, and is explicitly out of scope here.
- `grep -c '"tools": {}' claude/skills/registry.json` prints `1`. The block is real and empty.

`verify --structure` still has no caller. Its first one is `WO-20260824-2ad1` - `PR gate workflow: validate the bump intent and run the affected suites`, which is several tickets away.

Nothing was carried off `WO-20260824-de9e` - `Registry schema 2, with type derived from the tree and requires read from frontmatter`. All three acceptance criteria were met and evidenced separately against the real 43-skill tree.

Branch protection rules and required status checks are still absent, and are still on no ticket at all. That is load-bearing for `work-order.sh close`, which pushes its archive commit straight to `main` and only falls back to a PR when that push is rejected.

### Stale or false in the docs

`docs/superpowers/plans/2026-08-24-skills-package-manager-implementation.md` and `docs/superpowers/specs/2026-08-23-skills-package-manager-design.md` both still state the repository settings as `squash_merge_commit_message=COMMIT_MESSAGES`, `allow_merge_commit=true`, `allow_rebase_merge=true`, at `C2` in the plan and under `Repo settings, first` in the spec. All three were changed by `WO-20260824-cc71` - `Repo settings: squash-only, with the commit body taken from the PR description` and the stated values are false.

Both documents also still carry the `SessionStart` matcher question as open - in the plan at `C7` and in `E1.2`, in the spec under `Problem A - a sync fires while an agent is mid-task`. It was answered by `WO-20260824-0615` - `Confirm whether a SessionStart hook matcher filters by source`: matchers do filter by source, alternation is honoured, and the stdin-read fallback is dead.

Neither correction is this ticket's business. `WO-20260824-bb0d` - `setup.sh installs the skill-sync binary, then the SessionStart hook` touches the matcher material and `WO-20260824-8cd1` - `Rewrite root CLAUDE.md for merge-time allocation and the named main exception` touches the settings material.

The spec's `E1.5` section says the partial is "registered in the registry's `tools` block so a change to it forces a re-render everywhere". That is now true of the mechanism and not yet of the file - the block exists and is empty, and registering the partial is your `AC-H2`.

Root `CLAUDE.md` Rule 16 still requires a PR touching a skill to bump the version and ship a regenerated `registry.json` by hand. That is true today. It does **not** bind this ticket the way it bound the last one: `claude/tools/` is not under `claude/skills/`, so a PR that only adds the template touches no skill and owes no bump. It becomes false at `WO-20260824-8cd1` - `Rewrite root CLAUDE.md for merge-time allocation and the named main exception`.

`claude/skills/skill-versioning/SKILL.md` is current. It documents schema 2, the derived `type`, the comma-separated `requires`, the `tools` block and the marker convention, and gives the check count as 103. If you change the suite, that number moves with it.

### Your scope

One file and one registry entry: `claude/tools/partials/read-only-notice.md.tmpl`, and the `read-only-notice` entry it causes `render_tools` to emit.

The template holds the six-line notice with the skill's own name substituted in one place. Its rendered output must be byte-identical to `claude/skills/work-order/SKILL.md` lines 9 to 14 as they stand today. Byte-identical is the acceptance criterion because it is the only way to prove this is a refactor and not a rewrite.

The tool name inside the notice is hardcoded to `skill-sync.sh` and is **not** a placeholder. After this work `skill-update.sh` no longer installs synced skills, so a rendered copy naming it would be wrong.

**The template must carry a version marker in its first 20 lines**, because `render_tools` reads one:

```
<!-- skill-tool-version: 1.0.0 -->
```

The marker token is deliberately not `version:` - it cannot then be confused with a `version:` in prose, and it reads under any comment syntax. `read_tool_version` in `claude/skills/skill-versioning/scripts/skill-version.sh` is the reader.

Out of scope, and named because they are the obvious next thoughts: removing the notice from any `SKILL.md`, which is the pilot and epic 2; making the tool name a placeholder; and writing the renderer itself, which belongs to `skill-sync.sh`.

### Before you start

Settle how the version marker survives the byte-identical requirement. It is the one thing in this ticket that the ticket text does not anticipate, because the marker convention was introduced by the predecessor after this ticket was written.

The marker has to be inside the template's first 20 lines for `render_tools` to find it, and it must not appear in the rendered output, which has to match six specific lines exactly. So something has to strip it. Decide between a template whose first line is the marker and a renderer that drops any leading `<!-- skill-tool-version: -->` line, and a template that is stored with the marker in a position the substitution step naturally discards.

Whichever you pick, write the rule down in the template itself. The renderer that has to honour it does not exist yet - it is `WO-20260824-5b89` - `skill-sync.sh part one: resolution, and the tools test tree it is proved in` and the one after it - and a convention that lives only in this entry will not survive to meet it.

### Read in this order

1. Root `CLAUDE.md`. Rules 12, 14, 15 and 17 bear on this work. Rule 16 does not, because `claude/tools/` is not under `claude/skills/`. There is no `CONTEXT_STATE.md` in this repository.
2. This entry, which is the top entry of `HYDRATION.md`. Read only this one.
3. The note on the epic `WO-20260824-f1a5` - `Skills package manager: prove the path on one skill`, newest first. It records why the `tools` block ships empty and why building the tools first was not available.
4. `docs/superpowers/specs/2026-08-23-skills-package-manager-design.md`, the section `The read-only notice becomes a partial`. It is the argument for the change and it quotes the six lines.
5. `docs/superpowers/plans/2026-08-24-skills-package-manager-implementation.md`, section `E1.5`.
6. The ticket file: `work-orders/WO-20260824-f1a5/WO-20260824-2136-extract-the-read-only-notice-into-a-single-rende.md`.
7. `claude/skills/work-order/SKILL.md` lines 9 to 14, which are the bytes you have to reproduce.
8. `claude/skills/skill-versioning/scripts/skill-version.sh`, `render_tools` and `read_tool_version` together, before writing the template.

### Reuse, it is proven

`render_tools` already does everything the registry side of this ticket needs. Drop the file at `claude/tools/partials/read-only-notice.md.tmpl` with a marker in it and the entry appears on its own. There is no edit to make in `skill-version.sh` and no table to extend - `read-only-notice` is already registered in `TOOLS_REGISTERED`.

`render_registry` is a pure function of the tree: same tree in, same bytes out. That property is what lets `verify` be a string comparison instead of a JSON parser. Adding the template changes the registry, so the registry has to be regenerated in the same commit or `verify` goes red.

The notice is identical in all 43 files except for the skill's own name in one URL. `claude/skills/work-order/SKILL.md` lines 9 to 14 are the canonical copy and the ones the acceptance criterion names.

`claude/skills/skill-versioning/testing/run-tests.sh` builds a fixture tools tree at `$WORK/tools` in section 6b and proves the populated path against it. That is the pattern to copy if this ticket wants its own assertions, and it needs neither git nor a network.

`claude/skills/work-order/scripts/work-order.sh` owns every ticket transition. Never hand-edit a ticket file. `note` is the only way a note reaches a ticket, and `evidence` is the only way a criterion gets ticked.

`claude/skills/hydration-prompt/scripts/hydration.sh` owns `HYDRATION.md`. Run `check --body-file` before `add`; `add` refuses a body that fails `check`.

`gh` is authenticated and works in this repository. `gh-axi` wraps it and is preferred where it fits.

### The verification ladder

Rung 1, free: `head -20 claude/tools/partials/read-only-notice.md.tmpl` shows the marker. If it does not, `skill-version.sh` dies rather than rendering a version-less entry, and it dies inside `render_registry`, which means `bump`, `init` and `verify` all fail at once.

Rung 2, cheap: substitute the skill name by hand in a container and `diff` the result against `claude/skills/work-order/SKILL.md` lines 9 to 14. That is `AC-H1`, and byte-identical means `diff` is silent and exits 0. Minimal images ship neither `cmp` nor `diff` - check before depending on either, or compare with a shell string test.

Rung 3: `skill-version.sh init` then `grep '"read-only-notice"' claude/skills/registry.json` shows the entry with a version and a `sha256`. That is `AC-H2`.

Rung 4: `skill-version.sh verify` exits 0 on the branch. The template is new, so the registry moves; the run is green only if the regenerated registry is committed with it.

Rung 5: `bash claude/skills/skill-versioning/testing/run-tests.sh` in Podman, the full suite, with the 103 existing checks still green.

### Traps, already paid for

The template exists but carries no marker, and every `skill-version.sh` subcommand dies at once. `render_tools` treats a registered tool present without a `skill-tool-version:` as a hard failure, on purpose - an entry with no version is one no consumer can compare. The message names the file and the marker it wants.

`render_registry` no longer reproduces the file byte for byte and every skill reads as drifted. A trailing newline, a key order change or a space after a colon does it. Compare the rendered output to the file before touching any test.

A `grep -q` in a pipeline reports "no match" when it matched. `grep -q` closes the pipe on the first hit, the upstream command dies of SIGPIPE, and `pipefail` turns that into a non-zero pipeline. Capture to a variable and grep the variable. `diff_check` in `skill-version.sh` is written that way and says why.

The test suite passes on a machine and fails in the container, or the reverse. Minimal images ship neither `cmp` nor `diff`, and Git Bash on Windows has no `flock`. Root `CLAUDE.md` Rule 17 lists what actually bites.

A markdown formatter re-pads tables in a file you only meant to add one line to. It is a `PostToolUse` hook in the machine's global `~/.claude/settings.json`, not in this repository's `.claude/settings.json`, so the churn is local and does not belong in a diff. `git diff --stat` before committing; a two-line change that reports forty is this. `git checkout HEAD -- <file>` and re-apply with `sed`, which does not trip the hook.

`work-order.sh close` refuses with "reached done on the feature branch, but main's copy still says 'in-review'". `done` and the hydration entry are both meant to ride the ticket's own pull request, before it merges. Merging first strands them and costs a second pull request to carry them, which is precisely the thing `close` was rewritten to avoid. Run `submit --pr N`, then `done`, then write the entry, then push - all onto the same PR.

`work-order.sh close` refuses with "working tree is dirty". It stages and commits only `work-orders/`, so anything else has to be committed before it runs.

A command reports success and did nothing. A prompt with no TTY takes its default and exits 0. Assert the post-state, never `$?` alone.

`git merge --ff-only origin/main` refuses with "diverging branches". You are in a treehouse slot at detached HEAD, not in `/home/luna/dotfiles`. Check `git branch --show-current` first.

`git rebase` refuses with "cannot rebase: You have unstaged changes", immediately after `work-order.sh start`. `start` writes the ticket file, `INDEX.md` and the epic README and leaves them uncommitted. Commit them before rebasing.

### Workflow

```bash
WO=claude/skills/work-order/scripts/work-order.sh
HP=claude/skills/hydration-prompt/scripts/hydration.sh
SV=claude/skills/skill-versioning/scripts/skill-version.sh

bash $WO show    --project . --id WO-20260824-2136
bash $WO start   --project . --id WO-20260824-2136   # creates the branch, leaves files uncommitted

# ... write the template, in a container ...

bash $SV init                                        # regenerates registry.json; no bump is owed
bash $SV verify                                      # this one has to be green

bash $WO evidence --project . --id WO-20260824-2136 --index 1 --observed "..."
bash $WO evidence --project . --id WO-20260824-2136 --index 2 --observed "..."

bash $HP check   --project . --body-file /tmp/entry.md
bash $HP add     --project . --id <next> --title "<next title>" --body-file /tmp/entry.md

git push -u origin <branch>
gh pr create --base main --title "..." --body-file <file>

bash $WO submit  --project . --id WO-20260824-2136 --pr <N>
bash $WO done    --project . --id WO-20260824-2136   # on the branch, BEFORE the merge
git commit && git push                               # rides the same PR

# after the merge
bash $WO close   --project . --id WO-20260824-2136 --dry-run
bash $WO close   --project . --id WO-20260824-2136
```

`approve` is already done for every ticket in both epics and must not be run again.

The pull request description is the merge commit body verbatim. Write it as something worth reading on `main`, because that is where it ends up.

### Conventions

Every reference to a work-order in a chat reply carries the ticket ID and its full title joined by a dash. A bare ID is a defect, and so is "the next ticket" or "the blocked one".

Feature branches only. `main` is never written directly by hand. The one exception is `work-order.sh close`, which commits its archive straight to `main` and falls back to a pull request only when that push is rejected.

Rule 14 has no size threshold. A single `--help` run whose purpose is to check that something works goes in a container.

<!-- hydration-entry: WO-20260824-de9e -->
## WO-20260824-de9e - Registry schema 2, with type derived from the tree and requires read from frontmatter
_Generated 2026-08-24 by hydration.sh. Newest entry._

### Ticket

`WO-20260824-de9e` - `Registry schema 2, with type derived from the tree and requires read from frontmatter`. Position 4 of 21 children across two epics.
Predecessor `WO-20260824-6acf` - `Split verify into a structure check and a full check, and delete the notice assertion`, merged, closed and archived.

It is the second of the two tickets that touch `skill-version.sh`, and it is the larger one: rendering, frontmatter reading, a hash block, and a new distinct failure mode. Poker put it at 5 points against the split's 3.

`WO-20260824-2136` - `Extract the read-only notice into a single rendered partial` is also startable and is not blocked by this. Take that one instead if the tools directory is the more useful thing to have first; the two do not collide.

### What just landed

`verify` has two forms, and the read-only notice check is gone.

```
verify              versions present + registry.json matches render_registry
verify --structure  versions present + this branch's diff touches no version:
                    and no registry.json
```

`--structure` says nothing about whether the registry matches the tree. That is the entire point: under merge-time allocation a skill PR edits a skill and leaves the registry alone, and plain `verify` calls that state `drifted` - correctly, because on `main` it would be.

Measured on the branch before its own Rule 16 bump, in the container with the repo mounted read-only: `--structure` printed `base: origin/main` and `ok - 43 skills versioned, no version: or registry.json in the diff` at rc 0, and plain `verify` printed `drifted skill-versioning` with both hashes at rc 1. Two exit codes, one tree.

The diff half resolves a base from the first of `origin/main` or `main` that exists, `--base <ref>` overrides it, and it compares against the working tree rather than `HEAD` so an uncommitted hand-edit is caught before it is ever committed. Outside a git repository it fails and says so rather than passing with nothing checked.

The notice check at `skill-version.sh:192-197` is deleted, and `SKILL_SRC_URL` with it - it had no other caller. Nothing replaced it. `verify` now asserts the notice neither present nor absent, which is the only state that holds while the repository is mid-rollout.

The suite is at 72 checks, 26 negative, green in Podman on `bitnami/git` pinned by digest with `--network=none`. Section 5 is new and drives `--structure` against a real git repository with its skills under `claude/`, because every assertion that form makes is about a diff.

### What is NOT done

Nothing has been built in either epic beyond `skill-version.sh`. Eighteen of the twenty-one tickets have never been started and none of them has a branch.

Each of these is a command whose output proves the claim, measured on `main` after this ticket merged:

- `ls claude/tools` fails. No `skill-sync.sh`, no `skill-onboard.sh`, no notice partial, no tools test suite.
- `git ls-files .github/workflows` prints nothing. There is no PR gate and no publisher, so nothing yet calls `verify --structure` and nothing yet reads the `Bump:` trailer.
- `head -c 40 claude/skills/registry.json` shows `"schema": 1`. **This is your ticket.**
- `grep -l "This copy is read-only" claude/skills/*/SKILL.md | wc -l` prints `43`. Every skill still carries the inline notice. Only the check on it is gone.
- `grep -c 'requires' claude/skills/skill-versioning/scripts/skill-version.sh` prints `0`, and no `SKILL.md` carries a `requires:` key.

`verify --structure` exists but has no caller. Its first one is `WO-20260824-2ad1` - `PR gate workflow: validate the bump intent and run the affected suites`, which is blocked on `WO-20260824-efb0` - `skill-sync.sh part two: build, swap, receipt, and self-update` and is several tickets away.

Nothing was carried off `WO-20260824-6acf` - `Split verify into a structure check and a full check, and delete the notice assertion`. Both acceptance criteria were met and evidenced separately.

Branch protection rules and required status checks are still absent, and are still on no ticket at all.

### Stale or false in the docs

`docs/superpowers/plans/2026-08-24-skills-package-manager-implementation.md` and `docs/superpowers/specs/2026-08-23-skills-package-manager-design.md` both still state the repository settings as `squash_merge_commit_message=COMMIT_MESSAGES`, `allow_merge_commit=true`, `allow_rebase_merge=true`, at `C2` in the plan and under `Repo settings, first` in the spec. All three were changed by `WO-20260824-cc71` - `Repo settings: squash-only, with the commit body taken from the PR description` and the stated values are false.

Both documents also still carry the `SessionStart` matcher question as open - in the plan at `C7` and in `E1.2`, in the spec under `Problem A - a sync fires while an agent is mid-task`. It was answered by `WO-20260824-0615` - `Confirm whether a SessionStart hook matcher filters by source`: matchers do filter by source, alternation is honoured, and the stdin-read fallback is dead.

Neither correction is worth a fix-up commit on its own, and neither is this ticket's business. `WO-20260824-bb0d` - `setup.sh installs the skill-sync binary, then the SessionStart hook` touches the matcher material and `WO-20260824-8cd1` - `Rewrite root CLAUDE.md for merge-time allocation and the named main exception` touches the settings material; each can correct its own in passing.

Root `CLAUDE.md` Rule 16 still requires a PR touching a skill to bump the version and ship a regenerated `registry.json` by hand. That is true today and **it binds this ticket**, which edits `claude/skills/skill-versioning/`. It becomes false at `WO-20260824-8cd1` - `Rewrite root CLAUDE.md for merge-time allocation and the named main exception`, and not before.

One consequence of that is worth expecting rather than discovering. Because Rule 16 obliges the branch to carry the bump and the regenerated registry, `verify --structure` reports both and exits 1 on this ticket's own PR, exactly as it did on the last one. Plain `verify` is the one that has to be green. That inverts at `WO-20260824-8cd1`, and it is on the predecessor's ticket as a note.

`claude/skills/skill-versioning/SKILL.md` is current. It documents both forms of `verify`, states that the notice check is gone and why the middle state is deliberate, and gives the check count as 72. If you change the suite, that number moves with it.

### Your scope

One script, its suite, and two frontmatter keys: `claude/skills/skill-versioning/scripts/skill-version.sh`, `claude/skills/skill-versioning/testing/run-tests.sh`, and `requires: work-order` added to `claude/skills/living-docs/SKILL.md` and `claude/skills/cartography/SKILL.md`.

`render_registry` emits schema 2. Per decision 21, `type` is **derived from the directory the entry was found in and never declared** - `skill` or `agent`, routing only. `requires` is an optional frontmatter key, read with one line of `awk`, comma-separated, no YAML list, because Git Bash has no YAML parser and Rule 17 makes that a portability defect rather than a preference.

`verify` gains one new failure that is its own thing rather than drift: a schema mismatch. Today a registry written by an older generator reads as every skill having drifted at once, which names 43 skills and explains none of them.

`verify` also asserts that every name in a `requires:` resolves to a skill that exists. A typo'd dependency that resolves to nothing is the failure mode the auto-install path cannot recover from later.

**One thing to settle before writing the tools block.** The ticket asks for a `tools` block carrying `skill-sync` and `read-only-notice`, each with a version and a hash. Neither file exists: `claude/tools/` is created by `WO-20260824-2136` - `Extract the read-only notice into a single rendered partial` and `WO-20260824-5b89` - `skill-sync.sh part one: resolution, and the tools test tree it is proved in`. `render_registry` is a pure function of what is on disk and cannot hash a file that is not there. Decide deliberately between rendering the block only for tools that exist, and taking `WO-20260824-2136` first so the partial is there to hash. Do not hash a placeholder - a stable hash over a file nobody wrote is the kind of green that stays green after the real file lands.

Out of scope, and named because they are the obvious next thoughts: declaring `type` in frontmatter, which decision 21 rejected outright; YAML list syntax for `requires`; and soft or optional dependencies.

### Before you start

Settle the `tools` block question above. It is the one thing in this ticket that cannot be answered from the ticket text alone, and it decides whether this ticket or `WO-20260824-2136` - `Extract the read-only notice into a single rendered partial` goes first.

### Read in this order

1. Root `CLAUDE.md`. Rules 12, 14, 15, 16 and 17 bear on this work. There is no `CONTEXT_STATE.md` in this repository, so the usual second step does not apply.
2. This entry, which is the top entry of `HYDRATION.md`. Read only this one. The entries below it are superseded history.
3. `docs/superpowers/specs/2026-08-23-skills-package-manager-design.md`, decision 21. It is the argument for deriving `type` rather than declaring it, and the reason `requires` is comma-separated.
4. `docs/superpowers/plans/2026-08-24-skills-package-manager-implementation.md`, section `E1.4`.
5. The ticket file: `work-orders/WO-20260824-f1a5/WO-20260824-de9e-registry-schema-2-with-type-derived-from-the-tre.md`.
6. `claude/skills/skill-versioning/scripts/skill-version.sh`, `render_registry` and `hash_skill` together, before changing either.
7. `claude/skills/skill-versioning/testing/run-tests.sh`, section 5, which is the newest case shape in the file and the one a schema case should look like.

### Reuse, it is proven

`render_registry` is already a pure function of the tree: same tree in, same bytes out. That property is what lets `verify` be a string comparison instead of a JSON parser, and it is why the registry carries no timestamp. Schema 2 keeps it or it breaks `verify`.

`read_version` is the frontmatter reader to copy for `requires:`. It reads the leading fenced block only, so a `requires:` line in prose is ignored - which is the whole reason it is written that way.

`claude/skills/skill-versioning/testing/run-tests.sh` is the suite to extend, not to replace. Section 5 builds a real git repository fixture; sections 2 to 4 use a plain directory. A schema case needs neither git nor a network.

`claude/skills/work-order/scripts/work-order.sh` owns every ticket transition. Never hand-edit a ticket file. `note` is the only way a note reaches a ticket, and `evidence` is the only way a criterion gets ticked.

`claude/skills/hydration-prompt/scripts/hydration.sh` owns `HYDRATION.md`. Run `check --body-file` before `add`; `add` refuses a body that fails `check`.

`claude/skills/container-sandbox/SKILL.md`, and `references/skill-testing.md` beside it, define how a skill's own bundled scripts are tested. This is an ordinary bash script with an ordinary suite, so Rule 14 applies with full force and there is no exemption to claim.

`gh` is authenticated and works in this repository. `gh-axi` wraps it and is preferred where it fits.

### The verification ladder

Rung 1, free: `bash -n claude/skills/skill-versioning/scripts/skill-version.sh`. A syntax error in a script that is only ever run through a container is otherwise found several minutes later.

Rung 2, cheap: render the registry and compare it to the committed file by hand, in a container. `render_registry` reproducing `registry.json` byte for byte is `AC-H1` and it is the cheapest of the three to check.

Rung 3: `grep` the rendered registry for the two `work-order` edges and for the absence of any other, which is `AC-H2`. Assert both halves - that they are there, and that nothing else has one.

Rung 4: a deliberately mistyped `requires:` fails `verify`, which is `AC-H3`. Assert the exit code deliberately, with `if ! cmd; then` or `cmd; rc=$?`. A check that is expected to fail is the one place where `set -e` will end the run for you and report it as an error rather than as the assertion passing.

Rung 5: `bash claude/skills/skill-versioning/testing/run-tests.sh` in Podman, the full suite, with the new cases included and the 72 existing ones still green.

### Traps, already paid for

`render_registry` no longer reproduces the file byte for byte and every skill reads as drifted at once. A trailing newline, a key order change, or a space after a colon does it. Compare the rendered output to the file before touching any test.

`verify` passes when it should have failed. An unknown flag was accepted and ignored. `verify` now rejects unknown options, and the suite asserts it - keep that assertion working if you add a flag.

A `grep -q` in a pipeline reports "no match" when it matched. `grep -q` closes the pipe on the first hit, the upstream command dies of SIGPIPE, and `pipefail` turns that into a non-zero pipeline. Capture to a variable and grep the variable. `diff_check` in `skill-version.sh` is written that way and says why.

The test suite passes on a machine and fails in the container, or the reverse. Minimal images ship neither `cmp` nor `diff`, and Git Bash on Windows has no `flock`. Root `CLAUDE.md` Rule 17 lists what actually bites.

`skill-version.sh verify` refuses the PR with a version and registry mismatch. The skill was edited without a bump. Rule 16, and it applies to `skill-versioning` editing itself.

A command reports success and did nothing. A prompt with no TTY takes its default and exits 0. Assert the post-state, never `$?` alone.

A loop over IDs passes every ID as one argument. This shell is zsh, which does not word-split an unquoted parameter the way bash does. Use `while read -r`, not `for x in $LIST`.

`git merge --ff-only origin/main` refuses with "diverging branches". You are in a treehouse slot at detached HEAD, not in `/home/luna/dotfiles`. Check `git branch --show-current` first.

`git rebase` refuses with "cannot rebase: You have unstaged changes", immediately after `work-order.sh start`. `start` writes the ticket file, `INDEX.md` and the epic README and leaves them uncommitted. Commit them before rebasing.

`work-order.sh done` refuses with "status is 'in-progress'; this command requires one of: in-review". `done` follows `submit --pr N`, so the pull request has to exist before `done` can be run. Open the PR, `submit`, `done`, then commit and push again onto the same PR.

### Workflow

```bash
WO=claude/skills/work-order/scripts/work-order.sh
HP=claude/skills/hydration-prompt/scripts/hydration.sh
SV=claude/skills/skill-versioning/scripts/skill-version.sh

bash $WO show    --project . --id WO-20260824-de9e
bash $WO start   --project . --id WO-20260824-de9e   # creates the branch, leaves files uncommitted

# ... do the work, in a container ...

bash $SV bump    skill-versioning --minor            # Rule 16, and it writes registry.json too
bash $SV verify                                      # this one has to be green

bash $WO evidence --project . --id WO-20260824-de9e --index 1 --observed "..."
bash $WO evidence --project . --id WO-20260824-de9e --index 2 --observed "..."
bash $WO evidence --project . --id WO-20260824-de9e --index 3 --observed "..."
bash $WO note     --project . --id WO-20260824-de9e --text "..."

bash $HP check   --project . --body-file /tmp/entry.md
bash $HP add     --project . --id <next> --title "<next title>" --body-file /tmp/entry.md

git push -u origin <branch>
gh pr create --base main --title "..." --body-file <file>

bash $WO submit  --project . --id WO-20260824-de9e --pr <N>
bash $WO done    --project . --id WO-20260824-de9e   # on the branch, before the merge
git commit && git push                               # rides the same PR

# after the merge
bash $WO close   --project . --id WO-20260824-de9e --dry-run
bash $WO close   --project . --id WO-20260824-de9e
```

`approve` is already done for all 23 tickets and must not be run again.

The pull request description is the merge commit body verbatim. Write it as something worth reading on `main`, because that is where it ends up.

### Conventions

Every reference to a work-order in a chat reply carries the ticket ID and its full title joined by a dash. A bare ID is a defect, and so is "the next ticket" or "the blocked one".

Feature branches only. `main` is never written directly. The one exception to that rule does not exist yet and arrives with the publish workflow.

Squash is the only merge available in this repository. Merge commits and rebase merges are disabled at the repository level, so `gh pr merge --merge` and `--rebase` will be refused.

No em dashes anywhere. Use a plain dash.

No agent co-author line in a commit message, and no Claude attribution footer in a PR body. Root `CLAUDE.md` Rule 13 makes the second one absolute.

All testing runs in Podman, per Rule 14, with no size threshold. This ticket has no exemption to claim: it is a bash script with an existing suite.

Report failures as failures. A skipped step is not a completed one.

<!-- hydration-entry: WO-20260824-6acf -->
## WO-20260824-6acf - Split verify into a structure check and a full check, and delete the notice assertion
_Generated 2026-08-24 by hydration.sh. Newest entry._

### Ticket

`WO-20260824-6acf` - `Split verify into a structure check and a full check, and delete the notice assertion`. Position 3 of 21 children across two epics.
Predecessor `WO-20260824-0615` - `Confirm whether a SessionStart hook matcher filters by source`, merged, closed and archived.

This one writes code, unlike the two before it.
It changes one script and its own test suite, and it is a gate: `WO-20260824-2ad1` - `PR gate workflow: validate the bump intent and run the affected suites` cannot be written until `verify --structure` exists to be called.

### What just landed

An answer, and no code.

`SessionStart` matchers filter by source, and alternation in a matcher is honoured.
Measured on Claude Code 2.1.220 in a scratch project outside this repository, with three `SessionStart` entries whose commands appended the hook payload from stdin to a per-entry log.

```
source     matcher "startup"   matcher "startup|resume|clear"   matcher "" (control)
startup    fired               fired                            fired
resume     -                   fired                            fired
clear      -                   fired                            fired
compact    -                   -                                fired
```

The control entry is the part that makes the result trustworthy.
Without it, a hook that did not fire is indistinguishable from a session event that never happened, and the conclusion would have rested on an absence nobody could account for.

The consequence is that the design's safety property is available from the matcher alone.
`WO-20260824-bb0d` - `setup.sh installs the skill-sync binary, then the SessionStart hook` uses `"matcher": "startup|resume|clear"`, and that exact string is confirmed rather than assumed.
`WO-20260824-5b89` - `skill-sync.sh part one: resolution, and the tools test tree it is proved in` gains nothing.
It needs no stdin read and no early exit of its own, because the fallback branch did not happen.

The full truth table, how each of the four events was produced, and both consequences are on the ticket as a note.
Be aware that `work-order.sh note` stores a note as a single bullet, so the table is flattened there and is only readable as prose. The readable copy is this entry and the merge commit body.

The repository files that changed are the ticket file, `work-orders/INDEX.md`, the epic README, and `HYDRATION.md`.
`~/.claude/settings.json` was not touched, and the scratch project was deleted.

### What is NOT done

Nothing has been built in either epic. Nineteen of the twenty-one tickets have never been started and none of them has a branch.

Each of these is a command whose output proves the claim, measured on `main` after this ticket merged:

- `ls claude/tools` fails. No `skill-sync.sh`, no `skill-onboard.sh`, no notice partial, no tools test suite.
- `git ls-files .github/workflows` prints nothing. There is no PR gate and no publisher, so nothing yet reads the `Bump:` trailer that `WO-20260824-cc71` - `Repo settings: squash-only, with the commit body taken from the PR description` made possible.
- `head -c 40 claude/skills/registry.json` shows `"schema": 1`. Schema 2 is unwritten.
- `grep -l "This copy is read-only" claude/skills/*/SKILL.md | wc -l` prints `43`. Every skill still carries the inline notice.
- `grep -n "structure" claude/skills/skill-versioning/scripts/skill-version.sh` prints nothing. `verify` has one form, and it is the strict one.

Nothing was carried off `WO-20260824-0615` - `Confirm whether a SessionStart hook matcher filters by source` onto another ticket. Both of its acceptance criteria were met and evidenced separately.

Branch protection rules and required status checks are still absent, and are still on no ticket at all. That has not changed and is not this ticket's business.

### Stale or false in the docs

The design spec `docs/superpowers/specs/2026-08-23-skills-package-manager-design.md` carries an implementation note under `Problem A - a sync fires while an agent is mid-task` reading "Confirm that `SessionStart` matchers accept the source string before building on it. If they do not, the fallback is for `skill-sync` to read the source from the hook payload on stdin and exit early itself."
That is now answered. They do accept it, the fallback is dead, and the note is a question that has been closed.

The plan `docs/superpowers/plans/2026-08-24-skills-package-manager-implementation.md` says the same thing twice: at `C7 - the matcher is unconfirmed and gates the hook`, and in `E1.2`'s "if they do not" branch.
Both are answered by the same result. The gate is open and the fallback branch never fires.

Neither is worth a fix-up commit on its own. `WO-20260824-bb0d` - `setup.sh installs the skill-sync binary, then the SessionStart hook` is the ticket that touches this material and can correct both in passing.

The same two documents still state the repository settings as `squash_merge_commit_message=COMMIT_MESSAGES`, `allow_merge_commit=true`, `allow_rebase_merge=true`, at `C2` in the plan and under `Repo settings, first` in the spec.
Those were true when written on 2026-08-24 and are false now. All three were changed by `WO-20260824-cc71` - `Repo settings: squash-only, with the commit body taken from the PR description`.

Root `CLAUDE.md` Rule 16 still requires a PR touching a skill to bump the version and ship a regenerated `registry.json` by hand.
That is true today and **it binds this ticket**, which edits `claude/skills/skill-versioning/`. It becomes false at `WO-20260824-8cd1` - `Rewrite root CLAUDE.md for merge-time allocation and the named main exception`, and not before.

This repository has no `CONTEXT_STATE.md`. Several skills assume one and the `hydration-prompt` skill's flow references one. It genuinely does not exist here. Do not create one as a side effect of this ticket.

### Your scope

One script and its own test suite: `claude/skills/skill-versioning/scripts/skill-version.sh` and `claude/skills/skill-versioning/testing/run-tests.sh`.

Three changes, and they are one piece of work:

1. `verify --structure` is added. It asserts every skill has a `version:`, and that no `version:` line and no `registry.json` was hand-edited in the diff. It says **nothing** about whether `registry.json` matches the tree.
2. Plain `verify` keeps exactly the meaning it has today: everything `--structure` checks, plus `render_registry` matching `registry.json` on disk.
3. The read-only notice check is **deleted**. It is the `grep -qF 'This copy is read-only.'` block and the `SKILL_SRC_URL` branch beside it, around `skill-version.sh:192-197`, together with the `noro` variable and the failure message it prints.

The reason for the split is merge-time allocation: a skill PR will legitimately edit a skill and leave the registry alone, and that state has to pass the PR gate while still failing the publisher's strict check.

Do **not** add an assertion that the notice is absent. That is `WO-20260824-2ad1`'s successor `E2.7` and it cannot land until all 42 remaining `SKILL.md` files are clean. `C1` in the plan is the whole argument, and skipping the middle state is named there as the single most likely way to make the pilot PR fail its own gate.

Out of scope, and named because they are the obvious next thoughts: removing the notice from any `SKILL.md`, which `E2.6` owns, and writing the PR gate workflow that will call the new form, which is `WO-20260824-2ad1` - `PR gate workflow: validate the bump intent and run the affected suites`.

### Before you start

None.

One thing to be aware of rather than to resolve. This ticket edits a skill, so Rule 16 applies to its own PR, and the skill it edits is the one that owns versioning. Bump `skill-versioning` with its own script and ship the regenerated `registry.json`, exactly as any other skill edit would. There is nothing circular about it in practice; the script bumps itself the same way it bumps anything else. It is worth noticing before the PR rather than after `verify` refuses it.

### Read in this order

1. Root `CLAUDE.md`. Rules 12, 14, 15 and 16 bear on this work. There is no `CONTEXT_STATE.md` in this repository, so the usual second step does not apply.
2. This entry, which is the top entry of `HYDRATION.md`. Read only this one. The entries below it are superseded history.
3. `docs/superpowers/plans/2026-08-24-skills-package-manager-implementation.md`, section `C1 - the notice check cannot invert until the last SKILL.md is clean`, then `E1.3`. C1 is why the notice check is deleted rather than inverted.
4. The ticket file: `work-orders/WO-20260824-f1a5/WO-20260824-6acf-split-verify-into-a-structure-check-and-a-full-c.md`.
5. `claude/skills/skill-versioning/scripts/skill-version.sh`, the whole `verify` function, before changing any of it.
6. `claude/skills/skill-versioning/testing/run-tests.sh`, to see the case shape the two new cases have to match.

### Reuse, it is proven

`claude/skills/skill-versioning/scripts/skill-version.sh` already owns `version:` and `registry.json` as formats. Neither is ever hand-edited, and that rule applies to this ticket's own bump as much as to anyone else's.

`claude/skills/skill-versioning/testing/run-tests.sh` is the suite to extend, not to replace. Seven skills in this repository ship a `testing/run-tests.sh` and they share a shape.

`claude/skills/work-order/scripts/work-order.sh` owns every ticket transition. Never hand-edit a ticket file. `note` is the only way a note reaches a ticket, and `evidence` is the only way a criterion gets ticked.

`claude/skills/hydration-prompt/scripts/hydration.sh` owns `HYDRATION.md`. Run `check --body-file` before `add`; `add` refuses a body that fails `check`.

`claude/skills/container-sandbox/SKILL.md`, and `references/skill-testing.md` beside it, define how a skill's own bundled scripts are tested. Unlike the predecessor ticket, this one is an ordinary bash script with an ordinary suite, so Rule 14 applies with full force and there is no exemption to claim.

`gh` is authenticated and works in this repository. `gh-axi` wraps it and is preferred where it fits.

### The verification ladder

Rung 1, free: `bash -n claude/skills/skill-versioning/scripts/skill-version.sh`. A syntax error in a bash script that is only ever run through a container is otherwise found several minutes later.

Rung 2, cheap: `skill-version.sh verify --help` and `verify --structure --help`, in a container. Proves the new flag is wired into argument parsing at all, which is the failure that otherwise looks like a passing check because an unknown flag was silently ignored.

Rung 3, the actual acceptance criterion: on a branch that edits a skill and leaves the registry alone, `verify --structure` exits 0 and plain `verify` exits non-zero. Two exit codes, and they are the whole point of the ticket.

Rung 4: `bash claude/skills/skill-versioning/testing/run-tests.sh` in Podman, the full suite, both new cases included.

Assert the exit code deliberately, with `if ! cmd; then` or `cmd; rc=$?`. A check that is expected to fail is the one place where `set -e` will end the run for you and report it as an error rather than as the assertion passing.

### Traps, already paid for

`verify` passes when it should have failed. An unknown flag was accepted and ignored, so `--structure` did nothing and the strict path ran. Rung 2 exists for this.

The test suite passes on a machine and fails in the container, or the reverse. Minimal images ship neither `cmp` nor `diff`, and Git Bash on Windows has no `flock`. Root `CLAUDE.md` Rule 17 lists what actually bites.

`skill-version.sh verify` refuses the PR with a version and registry mismatch. The skill was edited without a bump. Rule 16, and it applies to `skill-versioning` editing itself.

A command reports success and did nothing. A prompt with no TTY takes its default and exits 0. Assert the post-state, never `$?` alone.

A loop over IDs passes every ID as one argument. This shell is zsh, which does not word-split an unquoted parameter the way bash does. Use `while read -r`, not `for x in $LIST`.

`git merge --ff-only origin/main` refuses with "diverging branches". You are in a treehouse slot at detached HEAD, not in `/home/luna/dotfiles`. Check `git branch --show-current` first.

`git rebase` refuses with "cannot rebase: You have unstaged changes", immediately after `work-order.sh start`. `start` writes the ticket file, `INDEX.md` and the epic README and leaves them uncommitted. Commit them before rebasing.

`work-order.sh done` refuses with "status is 'in-progress'; this command requires one of: in-review". `done` follows `submit --pr N`, so the pull request has to exist before `done` can be run. Open the PR, `submit`, `done`, then commit and push again onto the same PR.

### Workflow

```bash
WO=claude/skills/work-order/scripts/work-order.sh
HP=claude/skills/hydration-prompt/scripts/hydration.sh
SV=claude/skills/skill-versioning/scripts/skill-version.sh

bash $WO show    --project . --id WO-20260824-6acf
bash $WO start   --project . --id WO-20260824-6acf   # creates the branch, leaves files uncommitted

# ... do the work, in a container ...

bash $SV bump    skill-versioning --minor            # Rule 16, and it writes registry.json too
bash $SV verify

bash $WO evidence --project . --id WO-20260824-6acf --index 1 --observed "..."
bash $WO evidence --project . --id WO-20260824-6acf --index 2 --observed "..."
bash $WO note     --project . --id WO-20260824-6acf --text "..."

bash $HP check   --project . --body-file /tmp/entry.md
bash $HP add     --project . --id <next> --title "<next title>" --body-file /tmp/entry.md

git push -u origin <branch>
gh pr create --base main --title "..." --body-file <file>

bash $WO submit  --project . --id WO-20260824-6acf --pr <N>
bash $WO done    --project . --id WO-20260824-6acf   # on the branch, before the merge
git commit && git push                               # rides the same PR

# after the merge
bash $WO close   --project . --id WO-20260824-6acf --dry-run
bash $WO close   --project . --id WO-20260824-6acf
```

`approve` is already done for all 23 tickets and must not be run again.

The pull request description is the merge commit body verbatim. Write it as something worth reading on `main`, because that is where it ends up.

### Conventions

Every reference to a work-order in a chat reply carries the ticket ID and its full title joined by a dash. A bare ID is a defect, and so is "the next ticket" or "the blocked one".

Feature branches only. `main` is never written directly. The one exception to that rule does not exist yet and arrives with the publish workflow.

Squash is the only merge available in this repository. Merge commits and rebase merges are disabled at the repository level, so `gh pr merge --merge` and `--rebase` will be refused.

No em dashes anywhere. Use a plain dash.

No agent co-author line in a commit message, and no Claude attribution footer in a PR body. Root `CLAUDE.md` Rule 13 makes the second one absolute.

All testing runs in Podman, per Rule 14, with no size threshold. This ticket has no exemption to claim: it is a bash script with an existing suite.

Report failures as failures. A skipped step is not a completed one.

<!-- hydration-entry: WO-20260824-0615 -->
## WO-20260824-0615 - Confirm whether a SessionStart hook matcher filters by source
_Generated 2026-08-24 by hydration.sh. Newest entry._

### Ticket

`WO-20260824-0615` - `Confirm whether a SessionStart hook matcher filters by source`. Position 2 of 21 children across two epics.
Predecessor `WO-20260824-cc71` - `Repo settings: squash-only, with the commit body taken from the PR description`, merged, closed and archived.

This is a spike, not a build. Its whole output is a written answer to one question, and the answer changes what two later tickets are allowed to do.

### What just landed

Four repository settings on `jkkelley/dotfiles`, and no code.

```
squash_merge_commit_title:   COMMIT_OR_PR_TITLE -> PR_TITLE
squash_merge_commit_message: COMMIT_MESSAGES    -> PR_BODY
allow_merge_commit:          true               -> false
allow_rebase_merge:          true               -> false
```

Squash is now the only path into `main` for every pull request in this repository, and the squash commit body is the pull request description verbatim.

The proof that matters is not the read-back. Throwaway PR #56 carried `Bump: nothing=patch` in its description and deliberately carried no trailer in its branch commit message.
After the squash merge, `git log -1 --format=%B origin/main | git interpret-trailers --parse` printed exactly `Bump: nothing=patch`, at merge sha `d7f2f8c44ac2b010bed5cf09e43db20b636d5b64`.
The trailer had nowhere else to come from, so `PR_BODY` is confirmed to carry it through the real merge path rather than merely to have been accepted by the API.

The probe's scaffolding is gone. Branch `chore/trailer-probe` is deleted locally and on the remote, and `notes/trailer-probe.md` was removed in this ticket's own pull request, so `main` carries none of it.

The repository files that changed are the ticket file, `work-orders/INDEX.md`, the epic README, and `HYDRATION.md`. Nothing executable was written.

### What is NOT done

Nothing has been built in either epic. Twenty of the twenty-one tickets have never been started and none of them has a branch.

Each of these is a command whose output proves the claim, measured on `main` after this ticket merged:

- `ls claude/tools` fails. No `skill-sync.sh`, no `skill-onboard.sh`, no notice partial, no tools test suite.
- `git ls-files .github/workflows` prints nothing. There is no PR gate and no publisher, so nothing yet reads the trailer this ticket just made possible.
- `head -c 40 claude/skills/registry.json` shows `"schema": 1`. Schema 2 is unwritten.
- `grep -l "This copy is read-only" claude/skills/*/SKILL.md | wc -l` prints `43`. Every skill still carries the inline notice.

Deliberately out of scope on `WO-20260824-cc71` - `Repo settings: squash-only, with the commit body taken from the PR description`, and still absent: branch protection rules, and required status checks.
Status checks arrive with `WO-20260824-2ad1` - `PR gate workflow: validate the bump intent and run the affected suites`, which is blocked behind four other tickets. Branch protection is not on any ticket at all and is a decision the user has not been asked for.

Nothing was carried off this ticket onto another one. Both acceptance criteria were met and evidenced separately.

### Stale or false in the docs

`docs/superpowers/plans/2026-08-24-skills-package-manager-implementation.md` section `C2` states the live values as `squash_merge_commit_message=COMMIT_MESSAGES`, `allow_merge_commit=true`, `allow_rebase_merge=true`.
Those were true on 2026-08-24 when the plan was written and are false now. `WO-20260824-cc71` - `Repo settings: squash-only, with the commit body taken from the PR description` changed all three. The constraint C2 describes is satisfied, not pending.

`docs/superpowers/specs/2026-08-23-skills-package-manager-design.md` section `Repo settings, first` carries the same snapshot under the heading "Checked on 2026-08-24, and one of them would have killed this silently". Same correction. The `gh api -X PATCH` block immediately below it has been run, and does not need running again.

Neither of those is worth a fix-up commit on its own. They are historical statements about a moment, they are labelled with the date they were checked, and the tickets that touch those documents can correct them in passing.

Root `CLAUDE.md` Rule 16 still requires a PR touching a skill to bump the version and ship a regenerated `registry.json` by hand. That is still true today and must still be obeyed today.
It becomes false at `WO-20260824-8cd1` - `Rewrite root CLAUDE.md for merge-time allocation and the named main exception`, and not before. The new settings do not change it. A `Bump:` trailer reaching `main` does nothing at all until a publisher exists to read it.

This repository has no `CONTEXT_STATE.md`. Several skills assume one and the `hydration-prompt` skill's flow references one. It genuinely does not exist here. Do not create one as a side effect of this ticket.

### Your scope

One question, answered by watching real sessions, and the answer written into the ticket.

Does a `SessionStart` hook with `"matcher": "startup"` fire only on a startup, or does it fire on every source regardless of what the matcher says?

Build a scratch project outside this repository. Install a `SessionStart` hook whose matcher is the literal string `startup` and whose command appends its full stdin payload and a timestamp to a file. Then produce all four session events against that project: a fresh start, a resume, a clear, and a forced compact. Record which of the four caused the hook to fire.

The deliverable is a written decision, not a hook.

If matchers do filter, the answer is the matcher form `startup|resume|clear`, and `WO-20260824-bb0d` - `setup.sh installs the skill-sync binary, then the SessionStart hook` uses it.
If matchers do not filter, the answer is that `"matcher": ""` is used instead and `claude/tools/skill-sync.sh` must read the source out of the hook payload on stdin and exit early on `compact` by itself. That second outcome adds scope to `WO-20260824-5b89` - `skill-sync.sh part one: resolution, and the tools test tree it is proved in`, so say so plainly in the note if it happens.

Out of scope, and named because they are the obvious next thoughts: writing the real hook, which `WO-20260824-bb0d` - `setup.sh installs the skill-sync binary, then the SessionStart hook` owns, and editing `claude/tools/skill-sync.sh`, which does not exist yet and only gains the stdin read if the answer is no.

Do not modify `~/.claude/settings.json`. Every hook on this machine uses an empty matcher, that is precisely why the question is open, and changing the machine's real settings to run an experiment risks breaking every other project's session start.

Clean the scratch project up afterwards. It is scaffolding, not deliverable.

### Before you start

None.

One thing to be aware of rather than to resolve: forcing a compact costs a real context window, so it is the expensive event of the four and is worth doing last, after the cheap three are already recorded. The poker note on the ticket sized it at 3 points for exactly this reason.

### Read in this order

1. Root `CLAUDE.md`. Rules 12, 14 and 17 bear on this work. There is no `CONTEXT_STATE.md` in this repository, so the usual second step does not apply.
2. This entry, which is the top entry of `HYDRATION.md`. Read only this one. The entries below it are superseded history.
3. `docs/superpowers/plans/2026-08-24-skills-package-manager-implementation.md`, the section headed `Sequencing constraints`, specifically `C7`, and then `E1.2`. C7 is why this is a gate and not a detail.
4. The ticket file itself: `work-orders/WO-20260824-f1a5/WO-20260824-0615-confirm-whether-a-sessionstart-hook-matcher-filt.md`.
5. `docs/superpowers/specs/2026-08-23-skills-package-manager-design.md`, only the sections describing the SessionStart hook and the never-run-on-compact property. The rest is not needed for this ticket.

### Reuse, it is proven

`claude/skills/work-order/scripts/work-order.sh` owns every ticket transition. Never hand-edit a ticket file. `note` is the only way a note reaches a ticket, and `evidence` is the only way a criterion gets ticked.

`claude/skills/hydration-prompt/scripts/hydration.sh` owns `HYDRATION.md`. Run `check --body-file` before `add`; `add` refuses a body that fails `check`, which is how a malformed entry is kept out of the file.

`claude/skills/container-sandbox/SKILL.md` has a section on verifying a host CLI's behaviour by bind-mounting the real binary read-only. It is the right pattern for a great many things in these two epics, and it is the wrong pattern for this one. A `SessionStart` hook fires from a real interactive Claude Code session on this host; there is no way to produce a genuine resume or a genuine compact inside a container. Rule 14 is not waived, it simply has nothing to bite on, and the ticket's own test plan already calls this rung 5 and manual.

`gh` is authenticated and works in this repository. `gh-axi` wraps it and is preferred where it fits.

`git interpret-trailers --parse` is confirmed working end to end as of PR #56. Use it, not a regular expression, wherever a trailer is read.

### The verification ladder

Rung 1, free: `jq . <scratch>/.claude/settings.json`. Catches a malformed hook definition before any session is spent. A hook that fails to parse is silently absent, which looks identical to a matcher that filtered it out, and that is the one confusion that would make the whole result wrong.

Rung 2, cheap: start one session in the scratch project and confirm the hook file was appended to at all. If a plain startup does not fire, the hook is broken rather than the matcher being strict, and nothing further is worth doing until that is fixed.

Rung 3, the actual experiment: the resume and the clear. Two more sessions, no context cost worth counting.

Rung 4, expensive and last: the forced compact. This is the event the design's safety property is about, so it cannot be skipped, but it is the only one that costs a real context window.

Assert the post-state of the log file every time. Never assert on the exit status of the session command.

### Traps, already paid for

A hook appears not to fire and the conclusion is that matchers filter. The hook was actually never installed, because the settings file did not parse. Rung 1 exists for this.

A command reports success and did nothing. A prompt with no TTY takes its default and exits 0. Assert the post-state, never `$?`.

A loop over IDs passes every ID as one argument. This shell is zsh, which does not word-split an unquoted parameter the way bash does. Use `while read -r`, not `for x in $LIST`.

`git merge --ff-only origin/main` refuses with "diverging branches". You are in a treehouse slot at detached HEAD, not in `/home/luna/dotfiles`. Check `git branch --show-current` first.

`git rebase` refuses with "cannot rebase: You have unstaged changes", immediately after `work-order.sh start`. `start` writes the ticket file, `INDEX.md` and the epic README and leaves them uncommitted. Commit them before rebasing.

`work-order.sh done` refuses with "status is 'in-progress'; this command requires one of: in-review". `done` follows `submit --pr N`, so the pull request has to exist before `done` can be run. Open the PR, `submit`, `done`, then commit and push again onto the same PR.

### Workflow

```bash
WO=claude/skills/work-order/scripts/work-order.sh
HP=claude/skills/hydration-prompt/scripts/hydration.sh

bash $WO show    --project . --id WO-20260824-0615
bash $WO start   --project . --id WO-20260824-0615   # creates the branch, leaves files uncommitted

# ... do the work ...

bash $WO evidence --project . --id WO-20260824-0615 --index 1 --observed "..."
bash $WO evidence --project . --id WO-20260824-0615 --index 2 --observed "..."
bash $WO note     --project . --id WO-20260824-0615 --text "..."

bash $HP check   --project . --body-file /tmp/entry.md
bash $HP add     --project . --id <next> --title "<next title>" --body-file /tmp/entry.md

git push -u origin <branch>
gh pr create --base main --title "..." --body-file <file>

bash $WO submit  --project . --id WO-20260824-0615 --pr <N>
bash $WO done    --project . --id WO-20260824-0615   # on the branch, before the merge
git commit && git push                                # rides the same PR

# after the merge
bash $WO close   --project . --id WO-20260824-0615 --dry-run
bash $WO close   --project . --id WO-20260824-0615
```

`approve` is already done for all 23 tickets and must not be run again.

The pull request description is now the merge commit body verbatim. Write it as something worth reading on `main`, because that is where it ends up.

### Conventions

Every reference to a work-order in a chat reply carries the ticket ID and its full title joined by a dash. A bare ID is a defect, and so is "the next ticket" or "the blocked one".

Feature branches only. `main` is never written directly. The one exception to that rule does not exist yet and arrives with the publish workflow.

Squash is the only merge available in this repository now. Merge commits and rebase merges are disabled at the repository level, so `gh pr merge --merge` and `--rebase` will be refused.

No em dashes anywhere. Use a plain dash.

No agent co-author line in a commit message, and no Claude attribution footer in a PR body. Root `CLAUDE.md` Rule 13 makes the second one absolute.

All testing runs in Podman, per Rule 14, with no size threshold. This ticket's experiment cannot run in one, for the reason given above, and that is stated rather than quietly skipped.

Report failures as failures. A skipped step is not a completed one.

<!-- hydration-entry: WO-20260824-cc71 -->
## WO-20260824-cc71 - Repo settings: squash-only, with the commit body taken from the PR description
_Generated 2026-08-24 by hydration.sh. Newest entry._

### Ticket

`WO-20260824-cc71` - `Repo settings: squash-only, with the commit body taken from the PR description`. Position 1 of 21 children across two epics.
There is no predecessor. This is the first ticket of the first epic, `WO-20260824-f1a5` - `Skills package manager: prove the path on one skill`.

### What just landed

Five documentation and planning PRs, and nothing executable.

`docs/superpowers/specs/2026-08-23-skills-package-manager-design.md` is the design, 871 lines, with 21 numbered decisions.
Decision 19 puts the treehouse pool at `~/.treehouse/<repo>-<hash>/`, decision 20 fixes the four default skills as `work-order`, `living-docs`, `container-sandbox` and `context-compaction`, and decision 21 says `type` is derived from the tree it was found in and never declared, while `requires` is an optional comma-separated frontmatter key.

`docs/superpowers/plans/2026-08-24-skills-package-manager-implementation.md` is the implementation plan, 689 lines.
Its seven sequencing constraints C1 to C7 are the part worth reading twice.
Its `E1.x` and `E2.x` handles were always plan-internal and are now dead - every piece of work has a real ticket ID.

`docs/worktree-workflow.md` carries the answer to the treehouse gate. `treehouse return` does not lose unpushed commits, with or without `--force`. A dirty working tree is the case that changes code: `return` prompts, takes the no-TTY default, aborts, leaves the slot leased, and exits 0.

`claude/skills/container-sandbox/SKILL.md` gained a section on verifying a host CLI's behaviour by bind-mounting the real binary read-only. That is how the gate was answered and it is reusable.

PR #55 put 23 work-orders on `main`, all `ready`.

### What is NOT done

Nothing has been built. No line of either epic's implementation exists anywhere.

Measured on `main` at the time of writing, and each of these is a command whose output proves it:

- `ls claude/tools` fails. The directory does not exist, so neither `skill-sync.sh`, `skill-onboard.sh`, the notice partial, nor the tools test suite exist.
- `git ls-files .github/workflows` prints nothing. There is no PR gate and no publisher.
- `head -c 40 claude/skills/registry.json` shows `"schema": 1`. Schema 2 is unwritten.
- `grep -l "This copy is read-only" claude/skills/*/SKILL.md | wc -l` prints `43`. Every skill still carries the inline notice.
- `gh api repos/jkkelley/dotfiles --jq .squash_merge_commit_message` prints `COMMIT_MESSAGES`. This is the exact trap this ticket exists to close, and it is still open.

Every one of the 23 tickets is `ready`. None has been started, so none has a branch.

The 23 were approved with `--no-lavish`, and each records the reason: they were reviewed as one diff on PR #55 rather than in Lavish. That is an honest exception, not a skipped gate, but it is recorded on every ticket and a reader will see the warning.

### Stale or false in the docs

The previous top entry of `HYDRATION.md` said under `Before you start`: "Close the open decision on `type` and `requires`. Ask the user; do not choose." That is closed. Decision 21 in the design doc is the answer and it merged as PR #54. There is no open decision anywhere in this work.

Root `CLAUDE.md` Rule 16 still says a PR touching a skill must bump the version and ship a regenerated `registry.json` by hand. That is true today and must be obeyed today. It becomes false at `WO-20260824-8cd1` - `Rewrite root CLAUDE.md for merge-time allocation and the named main exception`, and not before. Do not pre-empt it.

The design doc's "Open" list still carries the question of who writes the generated skills table into `CLAUDE.md.tmpl`. The body of the same document already answers it: the sync writes it. The body wins, it is the more specific statement, and the sync is the only actor that knows what actually landed. The stale line is recorded in `WO-20260824-b21b` - `CLAUDE.md.tmpl: replace the session-start prose, add the skills markers, the treehouse policy and the documentation-lifetime rule` so it is corrected rather than rediscovered.

This repository has no `CONTEXT_STATE.md`. The `hydration-prompt` skill's one flow references one, and several skills assume it. It genuinely does not exist here. Do not create one as a side effect of this ticket.

### Your scope

Four repository settings, and one throwaway pull request that proves they work.

```bash
gh api -X PATCH repos/jkkelley/dotfiles \
  -f squash_merge_commit_title=PR_TITLE \
  -f squash_merge_commit_message=PR_BODY \
  -F allow_merge_commit=false \
  -F allow_rebase_merge=false
```

Then read all four back, then open a throwaway PR carrying a `Bump: nothing=patch` line in its description, merge it, and read the resulting commit on `main`.

The two acceptance criteria are deliberately different things. Reading the setting back proves the API call worked. Only reading the merged commit proves the trailer survives the path it will actually travel. Do not evidence the second criterion with the first one's output.

Out of scope, and named because they are the obvious next thoughts: branch protection rules, and required status checks. The status checks arrive with `WO-20260824-2ad1` - `PR gate workflow: validate the bump intent and run the affected suites`, which is a different ticket and is blocked behind four others.

Clean the throwaway PR's branch up afterwards. It is scaffolding, not deliverable.

### Before you start

None.

One thing to be aware of rather than to resolve: these settings are repository-wide and take effect immediately for every future merge in this repository, including the ticket's own. Disabling merge commits and rebase merges is intended, not collateral.

### Read in this order

1. Root `CLAUDE.md`. Rules 12 through 17 all bear on this work. There is no `CONTEXT_STATE.md` in this repository, so the usual second step does not apply.
2. This entry, which is the top entry of `HYDRATION.md`. Read only this one. The entries below it are superseded history.
3. `docs/superpowers/plans/2026-08-24-skills-package-manager-implementation.md`, the section headed `Sequencing constraints`, specifically C2. That is why this ticket is first.
4. The ticket file itself: `work-orders/WO-20260824-f1a5/WO-20260824-cc71-*.md`.
5. `docs/superpowers/specs/2026-08-23-skills-package-manager-design.md`, only the sections on merge-time allocation. The rest is not needed for this ticket.

### Reuse, it is proven

`gh` is authenticated and works in this repository. `gh-axi` wraps it and is preferred where it fits.

`claude/skills/work-order/scripts/work-order.sh` owns every ticket transition. Never hand-edit a ticket file. `note` is the only way a note reaches a ticket, and `evidence` is the only way a criterion gets ticked.

`git interpret-trailers --parse` is the reader the publisher will use later. Use the same command here, not a regular expression, so the proof matches what production will do.

`claude/skills/container-sandbox/SKILL.md` has a section on verifying a host CLI by bind-mounting the real binary read-only. Nothing in this ticket needs it, but it is the pattern for the tickets that do.

### The verification ladder

Rung 1, free: `gh api repos/jkkelley/dotfiles --jq '{squash_merge_commit_title,squash_merge_commit_message,allow_merge_commit,allow_rebase_merge}'`. Catches a typo'd field name or a `-f` that should have been `-F`. Booleans need `-F`; sending `allow_merge_commit=false` as a string with `-f` is accepted and does nothing.

Rung 2, one throwaway PR: merge it and run `git log -1 --format=%B origin/main | git interpret-trailers --parse`. This is the only rung that proves the thing the ticket is actually for, and it cannot be simulated. Everything downstream in both epics depends on it being true.

### Traps, already paid for

A `Bump:` trailer written in the PR description is absent from the merge commit, and every bump silently drops. `squash_merge_commit_message` defaults to `COMMIT_MESSAGES`, which concatenates the branch's commit messages and discards the PR body entirely. It currently reads `COMMIT_MESSAGES` in this repository, so this is the live state, not a hypothetical.

The settings read back correctly and the trailer still does not arrive. The API read only proves the call was accepted. The two acceptance criteria are separate for this reason.

A command reports success and did nothing. A prompt with no TTY takes its default and exits 0. This bit the treehouse gate work: `treehouse return` on a dirty tree aborts, leaks the slot, and exits 0. Assert the post-state, never `$?`.

A loop over IDs passes every ID as one argument. This shell is zsh, which does not word-split an unquoted parameter the way bash does. Use `while read -r`, not `for x in $LIST`.

`git merge --ff-only origin/main` refuses with "diverging branches". You are in a treehouse slot at detached HEAD, not in `/home/luna/dotfiles`. Check `git branch --show-current` first.

### Workflow

```bash
WO=claude/skills/work-order/scripts/work-order.sh

bash $WO show    --project . --id WO-20260824-cc71
bash $WO start   --project . --id WO-20260824-cc71

# ... do the work ...

bash $WO evidence --project . --id WO-20260824-cc71 --index 1 --observed "..."
bash $WO evidence --project . --id WO-20260824-cc71 --index 2 --observed "..."
bash $WO note     --project . --id WO-20260824-cc71 --text "..."

bash $WO submit  --project . --id WO-20260824-cc71 --pr <N>
bash $WO done    --project . --id WO-20260824-cc71     # on the branch, before the merge

# after the merge
bash $WO close   --project . --id WO-20260824-cc71 --dry-run
bash $WO close   --project . --id WO-20260824-cc71
```

`approve` is already done for all 23 tickets and must not be run again.

`done` is written on the feature branch before the PR lands, alongside the `HYDRATION.md` entry for the next ticket, so all of it rides one pull request.

### Conventions

Every reference to a work-order in a chat reply carries the ticket ID and its full title joined by a dash. A bare ID is a defect, and so is "the next ticket" or "the blocked one".

Feature branches only. `main` is never written directly. The one exception to that rule does not exist yet and arrives with the publish workflow.

No em dashes anywhere. Use a plain dash.

No agent co-author line in a commit message, and no Claude attribution footer in a PR body. Root `CLAUDE.md` Rule 13 makes the second one absolute.

All testing runs in Podman, per Rule 14, with no size threshold. This ticket has nothing to containerise - it is API calls and a merged PR - but the rule is not waived, it simply does not bite here.

Report failures as failures. A skipped step is not a completed one.

<!-- hydration-entry: none -->
## Poker and work-order tickets for the skills package manager
_Generated 2026-08-24 by hydration.sh. Newest entry._

### Ticket

No work order yet - creating them is this session's output. This is phases 4 and 5 of the skills package manager: discovery, design doc, implement doc, **poker**, **cut work-orders**, do work.

Predecessors: `#46` discovery, `#47` the two decided workflow docs, `#48` hydration init, `#49` the settled design, `#50` the implement-doc handoff, `#51` the host-CLI probe pattern, `#52` the implementation plan.

### What just landed

`#52` on `main` at `fe2504c`. The implementation plan exists, 689 lines, covering both epics in one document.

| File                                                                         | Lines | State                                                  |
| ---------------------------------------------------------------------------- | ----- | ------------------------------------------------------ |
| `docs/superpowers/plans/2026-08-24-skills-package-manager-implementation.md` | 689   | **the plan**. 23 tickets, seven sequencing constraints |
| `docs/superpowers/specs/2026-08-23-skills-package-manager-design.md`         | 871   | settled, binding on design. Not reopened               |
| `docs/skill-distribution-workflow.md`                                        | 81    | binding on merge-time allocation                       |
| `docs/worktree-workflow.md`                                                  | 248   | its backlog is now a pointer table into the plan       |
| `notes/skills-pm-discovery.md`                                               | 657   | measurements only, superseded where it differs         |

`#51` added a section to `container-sandbox` covering how to verify a host CLI's behaviour in a container, bumping it 1.0.2 to 1.1.0.

Two decisions closed, bringing the total to twenty:

- **19.** The treehouse pool stays user-level at `~/.treehouse/<repo>-<hash>/`. In-project `--root .` rejected.
- **20.** `project-scaffold`'s default manifest is four skills: `work-order`, `living-docs`, `container-sandbox`, `context-compaction`.

The gate that blocked the plan is answered. `treehouse return` does not lose unpushed commits - the branch ref stays in the repository and the object stays reachable, with or without `--force`.

### What is NOT done

**Nothing has been built. Three documents and one skill section, no implementation.** What proves it:

```sh
ls claude/tools/ 2>&1                    # No such file or directory
ls .github/ 2>&1                         # No such file or directory
git grep -n "skills.toml"                # docs only
git grep -n "SessionStart" -- claude/    # nothing
```

**No work-orders exist for any of this.** `work-orders/INDEX.md` does not carry a single ticket from the plan. Creating them is this session's deliverable.

**One decision in the plan is deliberately open and gates ticket E1.4.** Where `type` and `requires` are declared, so `render_registry` can read them. The plan lays out three shapes with their real costs under "One decision this plan cannot make". E1.4 does not start until it is closed, and E1.6 - the largest ticket - depends on E1.4.

**The repo settings are still wrong.** As of 2026-08-24 the live values remain `squash_merge_commit_message=COMMIT_MESSAGES`, `allow_merge_commit=true`, `allow_rebase_merge=true`. That is ticket E1.1, not a prerequisite for cutting tickets.

### Stale or false in the docs

| Where                                    | What is wrong                                                                                                          |
| ---------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| `notes/skills-pm-discovery.md`           | Predates both workflow docs and both revisions. The plan and the design are the current word wherever they differ      |
| Discovery note, "Decided" table          | Says semver runs on the PR branch and `skill-versioning` keeps its name. Both reversed                                 |
| Root `CLAUDE.md` Rule 16                 | Still says the author bumps and ships the registry. The rewrite text exists in the design doc, unapplied. Ticket E1.12 |
| Root `CLAUDE.md`, "main is written once" | No exception for the publish bot yet. Exact wording is in the design doc                                               |
| Every `SKILL.md`, lines 9-14             | Still carries the inline read-only notice. 43 files. Tickets E1.10 and E2.6                                            |
| `CLAUDE.md.tmpl:269-336`                 | 68 lines of prose session-start check that the hook replaces. Ticket E2.4                                              |
| Design doc, "Open, not designed here"    | Lists who writes the generated skills table. The doc body already answers it - the sync writes it. The body wins       |

### Your scope

**Two outputs, in order.**

**1. Poker.** Size the 23 tickets in the plan. Its "Estimate shape, for poker" section is the starting point, not the answer - it gives shape, not points. `project-manager` carries the estimation guidance, including the one rule that matters here: never average, discuss the outliers, because the highest and lowest estimators usually hold information the others do not.

The two that need the most conversation are `E1.6`, `skill-sync.sh`, which is the only ticket flagged large and carries a named split seam between resolution and application; and `E2.6`, removing the notice from 42 files, which is mechanical and is still the riskiest mechanical change in the plan.

**2. Cut the work-orders.** Two epics, each with children, using `work-order`. The plan's dependency graph is the source for `--depends-on` edges, and the seven sequencing constraints are the reason those edges exist - encode them, do not re-derive them.

**`E1.1` and friends are plan-internal handles, not ticket IDs.** They exist so this document and the plan can point at each other. Real IDs are minted by `work-order.sh new`, and every reference to one in a chat reply carries the ID and its full title joined by a dash.

Out of scope: writing `skill-sync.sh`, any workflow YAML, the notice partial, or a template edit. That is phase 6, one ticket per session.

### Before you start

**Close the open decision on `type` and `requires`.** Ask the user; do not choose. The three options and their costs are in the plan. It blocks `E1.4`, which blocks `E1.6`, so a ticket tree cut without it has a hole in the middle of Epic 1.

**Do not reopen the twenty closed decisions.** Eighteen in the design doc's table, two in the plan's. If sizing reveals one of them is unbuildable, say so plainly and stop - do not quietly substitute a different design.

**Two things are named in the design doc's "Open, not designed here" section and stay there.** They are not to be designed, raised as gaps, or folded into a recommendation.

**The seven sequencing constraints are not advisory.** C1 in particular: the notice check cannot invert until the last `SKILL.md` is clean, which is a three-step ordering across both epics. A ticket tree that lets `E2.7` run before `E2.6` makes the gate fail on 42 skills.

### Read in this order

1. `CLAUDE.md` at the repo root, all 17 rules. Rule 13 (no Claude footer in PR bodies) is absolute; Rule 14 (Podman) and Rule 16 (versioning) both change in this work.
2. `HYDRATION.md`, this entry only.
3. `docs/superpowers/plans/2026-08-24-skills-package-manager-implementation.md` in full. It is the document this session works from.
4. `docs/superpowers/specs/2026-08-23-skills-package-manager-design.md` for the reasoning behind any ticket whose point is unclear.
5. `claude/skills/work-order/SKILL.md`, "Cutting an epic and its children" at line 190.
6. `claude/skills/project-manager/SKILL.md`, "Estimation" at line 46.
7. `docs/skill-distribution-workflow.md` and `docs/worktree-workflow.md` only if a ticket's history is in question.

There is no `CONTEXT_STATE.md` in this repo.

### Reuse, it is proven

| Thing                                   | What it gives you                                            | Sharp edge                                                                          |
| --------------------------------------- | ------------------------------------------------------------ | ----------------------------------------------------------------------------------- |
| `work-order.sh new --json --parent`     | epics with children, a dependency graph, validated lifecycle | the tree in `INDEX.md` truncates long titles. A truncated title is not a title      |
| `project-manager` skill                 | estimation methods, and the never-average rule               | it is advice, not a script. Nothing enforces it                                     |
| The plan's dependency graph             | the `--depends-on` edges, already worked out                 | it encodes seven constraints. Dropping an edge silently drops the reason for it     |
| `skill-version.sh verify`               | pure pass/fail, green on `main` today                        | it must stay green. The publisher in `E1.8` treats a red `verify` as work to do     |
| `container-sandbox`, "host CLI" section | how to probe a tool already on the machine, added in `#51`   | assert the post-state, never `$?`. That is the whole point of the section           |
| `treehouse` v2.3.0, `~/.local/bin`      | worktree pool, detached-HEAD-when-idle, self-updating        | `return` on a dirty tree aborts and exits 0                                         |
| The 7 skills that ship a test suite     | the real input to the CI matrix in `E1.7`                    | the other 36 have nothing to run, which is why the matrix needs an empty-list guard |

### The verification ladder

1. `git grep` for the symbol. Catches a ticket referring to something that does not exist.
2. `bash -n` on any script. Catches the syntax error before a container spins up.
3. `skill-version.sh verify` locally. Catches an unversioned skill and a stale registry. It has caught both.
4. The skill's own `testing/run-tests.sh` in Podman, per Rule 14 and `claude/skills/container-sandbox/references/skill-testing.md`.
5. A real session in a scratch repo, for anything touching the `SessionStart` hook. The hook only proves itself by firing.

For this session the ladder mostly stops at rung 1, because the output is tickets. Rung 1 still matters: a ticket citing a file or line that does not exist is a ticket that wastes a whole session in phase 6.

### Traps, already paid for

- **`treehouse return` on a dirty tree prompts, takes the no-TTY default, aborts, leaves the slot leased, and exits 0.** Assert the post-state, never `$?`. Two tickets in the plan carry this in their acceptance criteria.
- **`squash_merge_commit_message` is `COMMIT_MESSAGES`.** The squash body comes from the branch's commit messages, not the PR description, so a `Bump:` trailer written in the description never reaches the commit and nothing reports an error.
- **`actions/checkout` defaults to `github.sha`**, the triggering commit, not the tip. A run whose sibling merged first sits on a stale tree and its push is rejected non-fast-forward, serialised or not.
- **An empty matrix is a hard error in GitHub Actions.** A docs-only PR emits `[]` and the workflow fails for no reason.
- **`find -type d` does not match symlinks to directories.** `skill_dirs()` uses it, so a compat symlink for the rename would be invisible to the registry - hiding the breakage rather than surfacing it.
- **Two PRs allocating the same version.** `#41` and `#42` both claimed `project-scaffold` 1.2.0. Git blocked them only because they happened to edit the same lines.
- **`git merge --ff-only origin/main` moves whatever branch you are on.** Check `git branch --show-current` first. A treehouse slot sits at detached HEAD and cannot be fast-forwarded at all, which is correct and is not an error to fix.
- **`-p` in a `claude` launch command.** It is `--print`: prints a reply and exits, so no session ever starts. The failure produces plausible output rather than an error.
- **A `SessionStart` hook that exits non-zero takes the session with it.** Always exit 0 and print the failure loudly.
- **Untracked files in the working directory are invisible to a session that starts in a worktree.** A whole session re-derived decided work because `docs/*.md` were never committed.

### Workflow

Cutting tickets is a docs change to `work-orders/`, so it follows the same shape as the last three sessions.

```sh
# isolated workspace
WT=$(treehouse get --lease --lease-holder "skills-pm-poker")
cd "$WT"
git switch -qc feat/skills-pm-work-orders origin/main

WO=.claude/skills/work-order/scripts/work-order.sh
EPIC=$(bash $WO new --json --top-level --type feature --priority p1 --title "..." | jq -r .id)
bash $WO new --parent "$EPIC" --type feature --title "..." --depends-on "..."

git add -A && git commit
git push -u origin HEAD
gh pr create --base main
gh pr merge <N> --squash

# close out - check the branch first, then return the slot and confirm it went
git branch --show-current
git checkout main && git fetch origin --prune && git merge --ff-only origin/main
treehouse return "$WT" --if-lease-holder "skills-pm-poker"
treehouse status                     # assert it is free. rc 0 does not prove it

HP=~/.claude/skills/hydration-prompt/scripts/hydration.sh
bash $HP check --project . --body-file /tmp/entry.md
bash $HP add   --project . --title "..." --body-file /tmp/entry.md
bash $HP command --project .
```

Ticket files touch nothing under `claude/skills/`, so no version bump and no registry regeneration. The moment a script or template is edited, Rule 16 applies.

### Conventions

Ticket references carry the ID **and** the full title, joined by a dash, on every mention. A bare ID is a defect, and so is a pointer with no name: "the next ticket", "the blocked one". Take the title from the ticket file, never from `INDEX.md`, whose tree truncates.

No em dashes anywhere, plain dashes only. No agent co-author lines in commits. No Claude attribution footer in a PR body, ever, per Rule 13.

Feature branches only; `main` is never written directly. All testing runs in Podman per Rule 14. Pin every version to an immutable digest per Rule 15; `:latest` is banned.

This repo is public. No real usernames, IPs, hostnames, registry paths, or credentials. The only documented exceptions are the two `jkkelley/dotfiles` public URLs - the registry raw URL and each skill's own source URL.

Report failing tests as failing, and say plainly what was skipped. "Completed" is wrong if anything was silently left out.

<!-- hydration-entry: none -->
## Implement doc for the skills package manager
_Generated 2026-08-24 by hydration.sh. Newest entry._

### Ticket

No work order. This is the **implement-doc** phase of the skills package manager, phase 3 of 6: discovery, design doc, **implement doc**, poker, cut work-orders, do work. Tickets are cut in phase 5, so there is deliberately no ID yet.

Predecessors: `#46` discovery and first design, `#47` the two decided workflow docs, `#48` hydration init, `#49` the settled design.

### What just landed

`#49` on `main` at `5c7973d`. The design doc is now **settled** - every open decision closed, every known defect corrected. 532 insertions, 88 deletions against the version merged in `#46`.

| File                                                                 | Lines | State                                          |
| -------------------------------------------------------------------- | ----- | ---------------------------------------------- |
| `docs/superpowers/specs/2026-08-23-skills-package-manager-design.md` | 871   | **settled**, the binding document              |
| `docs/skill-distribution-workflow.md`                                | 81    | decided 2026-08-22, binding on merge-time CI   |
| `docs/worktree-workflow.md`                                          | 243   | treehouse model, carries the real task list    |
| `notes/skills-pm-discovery.md`                                       | 657   | measurements only, superseded where it differs |

Eighteen decisions are recorded in the design doc's "Decisions, closed" table. The five that were awaiting sign-off are answered. The four defects merged in `#46` are fixed.

The corrections most likely to be re-derived if skimmed:

- **Version allocation is at merge time**, never on a PR branch.
- **Ownership is per-directory.** Sync never removes or rebuilds `.claude/skills/` itself, only the directories the manifest resolves to. Hand-authored project-only skills live beside the managed ones. The receipt records what sync owns.
- **The read-only notice becomes a rendered partial**, leaving all 43 `SKILL.md` files.
- **The matcher and the stamp solve two different problems.** The stamp cannot prevent a mid-task sync during auto-compact.

### What is NOT done

**Nothing has been built. No script, no workflow, no template change, no gitignore line exists.** What proves it:

```sh
ls claude/tools/ 2>&1                    # No such file or directory
ls .github/ 2>&1                         # No such file or directory
git grep -n "skills.toml"                # design docs only
git grep -n "SessionStart" -- claude/    # nothing
git grep -rn "Bump:" -- .github/         # nothing to search
```

**The implementation document does not exist.** That is this session's only deliverable.

**One design decision is untested and gates part of the plan.** What `treehouse return` does with unpushed commits on a branch. Idle slots are observed detached across all 15, but nothing has been run against a slot carrying unpushed work. `skill-onboard.sh` is specified in terms of treehouse, so this must be settled before the implement doc commits to that shape.

**The repo settings have not been changed.** As of 2026-08-24 the live values are still `squash_merge_commit_message=COMMIT_MESSAGES`, `allow_merge_commit=true`, `allow_rebase_merge=true`. The design specifies changing all three and the `Bump:` trailer does not work until they are. That is an implementation step, not a prerequisite for writing the doc.

### Stale or false in the docs

| Where                                               | What is wrong                                                                                                                                      |
| --------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| `notes/skills-pm-discovery.md`                      | Written before the two workflow docs were found, and before the 2026-08-24 revision. Treat the design doc as the current word wherever they differ |
| Discovery note, "Decided" table                     | Says semver runs on the PR branch and that `skill-versioning` keeps its name. Both reversed in `#49`                                               |
| Root `CLAUDE.md` Rule 16                            | Still says the author bumps and ships the registry. The rewrite text is in the design doc and has not been applied                                 |
| Root `CLAUDE.md`, "main is written once"            | Has no exception for the publish bot yet. The design doc contains the exact wording to add                                                         |
| Every `SKILL.md`, lines 9-14                        | Still carries the read-only notice inline. 43 files. Removing it is implementation work                                                            |
| `docs/worktree-workflow.md`, "After the compaction" | Six-item task list, predates the design. Reconcile it rather than treating it as a separate stream                                                 |

### Your scope

Produce **one** implementation document. Not the code.

`docs/superpowers/plans/2026-08-24-skills-package-manager-implementation.md`, matching the three plans already in that directory.

One document, not several. It covers both epics, because the second follows the procedure the first proves:

- **Epic 1, the pilot.** `hydration-prompt` through the whole pipeline end to end: trailer, PR gate, test matrix, merge-time bump, registry schema 2, sync into a real project. Nothing else moves until that path works.
- **Epic 2, the rollout.** The remaining 42 skills through the same procedure, closing with the `skill-versioning` to `skill-registry` rename.

It decides build order, file layout, test strategy per Rule 14, and how the six items in "After the compaction" at the bottom of `docs/worktree-workflow.md` interleave with the design. That list is the real backlog and predates the design doc; reconcile the two into one ordered plan.

Out of scope: writing `skill-sync.sh`, the workflow YAML, the notice partial, or any template edit. That is phase 6, after poker and tickets.

### Before you start

**Test `treehouse return` with unpushed commits.** Create a throwaway branch in a leased slot, commit without pushing, return the slot, and record what happens to the commit. `skill-onboard.sh`'s design depends on the answer. This is the one genuinely unknown thing.

**Do not reopen settled decisions.** The eighteen in the design doc's "Decisions, closed" table are closed. If implementation reveals one of them is unbuildable, say so plainly and stop - do not quietly pick a different design.

**Two things are flagged as future work and are not to be designed, mentioned as gaps, or folded into a recommendation:** the project-only skill system, and `justfile` coverage per Rule 17. Both are named in the design doc's "Open, not designed here" section, and that is where they stay.

**Ask before choosing** if the implement doc needs a decision the design doc does not contain. The design phase is over; a new decision made silently during implementation planning is how the two documents drift apart.

### Read in this order

1. `CLAUDE.md` at the repo root, all 17 rules. Rule 14 (Podman) and Rule 16 (versioning) both change in this work, and Rule 13 (no Claude footer in PR bodies) is absolute.
2. `HYDRATION.md`, this entry only.
3. `docs/superpowers/specs/2026-08-23-skills-package-manager-design.md` in full, all 871 lines. It is the binding document.
4. `docs/skill-distribution-workflow.md`, 81 lines. It is binding on merge-time allocation and explains why.
5. `docs/worktree-workflow.md`, especially "After the compaction" at the bottom.
6. `docs/superpowers/plans/2026-05-02-operator-implementation.md` for the shape an implementation doc takes in this repo.
7. `claude/skills/skill-versioning/scripts/skill-version.sh` - `hash_skill` at 102, `render_registry` at 115, `cmd_bump` at 150, `cmd_verify` at 174.
8. `notes/skills-pm-discovery.md` only if you need the measurement behind a decision.

There is no `CONTEXT_STATE.md` in this repo.

### Reuse, it is proven

| Thing                                   | What it gives you                                                                                                            | Sharp edge                                                                                      |
| --------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| `skill-version.sh`                      | `init`, `bump`, `verify`, `render_registry`, all deterministic                                                               | `cmd_bump` writes `SKILL.md` frontmatter _before_ the registry. Both land on `main`             |
| `skill-version.sh verify`               | a pure pass/fail check, ideal as a CI gate                                                                                   | must be split. The registry-in-sync half cannot pass on a PR branch under merge-time allocation |
| `skill-update.sh`                       | fetch a skill from GitHub with no dotfiles checkout; worktree-based PR flow                                                  | narrows to hand-authored skills only. It stops being part of the sync path                      |
| `treehouse` v2.3.0, `~/.local/bin`      | worktree pool, detached-HEAD-when-idle, self-updating Go binary                                                              | v2.0.0 removed `destroy --force`; scripts using it broke 2026-08-23                             |
| `project-scaffold/testing/`             | 14 numbered cases, `assert.sh`, `run-tests.sh`                                                                               | the pattern to copy for testing `skill-sync.sh`                                                 |
| The 7 skills that ship a test suite     | `cartography`, `context-compaction`, `hydration-prompt`, `living-docs`, `project-scaffold`, `skill-versioning`, `work-order` | the matrix's real input. The other 36 have nothing to run                                       |
| `.claude/cache/`                        | already gitignored, declared derived, never pruned by `cache.sh`                                                             | deleting it also deletes the sync tool's receipt, which is now the ownership record             |
| The `-axi` tools on `~/.npm-global/bin` | precedent for a PATH binary invoked from a `SessionStart` hook                                                               | they run at `timeout: 10`; a cold skill sync needs 30                                           |

### The verification ladder

1. `git grep` for the symbol. Catches an implement doc referring to something that does not exist.
2. `bash -n` on any script. Catches the syntax error before a container spins up.
3. `skill-version.sh verify` locally. Catches an unversioned skill, a missing notice, and a stale registry. It has caught all three.
4. The skill's own `testing/run-tests.sh` in Podman, per Rule 14 and `claude/skills/container-sandbox/references/skill-testing.md`.
5. A real session in a scratch repo, for anything touching the `SessionStart` hook. The hook only proves itself by firing.

Rung 5 matters more than usual here. The current session-start check is prose an agent may or may not follow, and the entire point of this work is replacing it with something that cannot be skipped. That property is unobservable from a unit test.

### Traps, already paid for

- **`squash_merge_commit_message` is `COMMIT_MESSAGES`.** The squash body is built from the branch's commit messages, not the PR description. A `Bump:` trailer written in the description never reaches the commit, the publisher finds nothing, and there is no error to trace.
- **`actions/checkout` defaults to `github.sha`.** That is the commit that triggered the run, not the current tip. A run whose sibling merged first is on a stale tree and its push is rejected non-fast-forward, serialised or not. `ref: main`.
- **An empty matrix is a hard error in GitHub Actions.** A docs-only PR emits `[]` and the workflow fails for no reason.
- **`find -type d` does not match symlinks to directories.** Relevant because `skill_dirs()` uses it, so a symlink in `claude/skills/` is invisible to the registry. This is why a compat symlink for the rename would have hidden the problem rather than surfacing it.
- **Two PRs allocating the same version.** `#41` and `#42` both claimed `project-scaffold` 1.2.0. Git blocked them only because they happened to edit the same lines.
- **`cannot remove a locked working tree` after a successful merge.** A hand-rolled worktree pinning the branch. Hit twice on 2026-08-23. treehouse's detached-HEAD invariant is the fix.
- **`git merge --ff-only origin/main` run from the wrong branch moves that branch.** Happened this session on `feat/stash-commit-unstash`, which had no commits of its own; restored to `a663655` with `git branch -f`. Check `git branch --show-current` before merging.
- **`-p` in a `claude` launch command.** It is `--print`: prints a reply and exits, so no session ever starts. The failure produces plausible output rather than an error.
- **Overwriting a running bash script in place.** Bash reads lazily by byte offset. `mv` preserves the inode; `cp` truncates it.
- **A `SessionStart` hook that exits non-zero takes the session with it.** Always exit 0 and print the failure loudly.
- **Untracked files in the working directory are invisible to a session that starts in a worktree.** A whole session re-derived decided work because `docs/*.md` were never committed.

### Workflow

No work order exists for this phase, so there is no `work-order.sh` sequence to run. Tickets get cut in phase 5, from the document this session produces.

```sh
# isolated workspace
WT=$(treehouse get --lease --lease-holder "skills-pm-implement-doc")
cd "$WT"
git switch -c feat/skills-pm-implementation-doc origin/main

# ... write the implementation doc ...

git add -A && git commit
git push -u origin HEAD
gh pr create --base main
gh pr merge <N> --squash --delete-branch

# close out - check you are on main first
git branch --show-current
git checkout main && git fetch origin --prune && git merge --ff-only origin/main
treehouse return "$WT" --if-lease-holder "skills-pm-implement-doc"

HP=~/.claude/skills/hydration-prompt/scripts/hydration.sh
bash $HP check --project . --body-file /tmp/entry.md
bash $HP add   --project . --title "..." --body-file /tmp/entry.md
bash $HP command --project .
```

Docs-only changes touch nothing under `claude/skills/`, so no version bump and no registry regeneration are required. The moment a template or script is edited, Rule 16 applies.

### Conventions

Ticket references carry the ID **and** the full title, joined by a dash, on every mention. A bare ID is a defect. So is a pointer with no name: "the next ticket", "the blocked one".

No em dashes anywhere, plain dashes only. No agent co-author lines in commits. No Claude attribution footer in a PR body, ever, per Rule 13.

Feature branches only; `main` is never written directly. All testing runs in Podman per Rule 14. Pin every version to an immutable digest per Rule 15; `:latest` is banned.

This repo is public. No real usernames, IPs, hostnames, registry paths, or credentials. The only documented exceptions are the two `jkkelley/dotfiles` public URLs - the registry raw URL and each skill's own source URL.

Report failing tests as failing, and say plainly what was skipped. "Completed" is wrong if anything was silently left out.

