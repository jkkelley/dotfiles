# Testing SOP

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [How the suite runs](#how-the-suite-runs)
- [010-new-happy](#010-new-happy)
- [020-new-refuses](#020-new-refuses)
- [030-figma-binding](#030-figma-binding)
- [040-evidence-snapshot](#040-evidence-snapshot)
- [050-lifecycle](#050-lifecycle)
- [060-approve-blocks](#060-approve-blocks)
- [070-cleanup-refuses-unmerged](#070-cleanup-refuses-unmerged)
- [080-cleanup-dry-run](#080-cleanup-dry-run)
- [090-done-archives-on-branch](#090-done-archives-on-branch)
- [095-cleanup-deletes-branches](#095-cleanup-deletes-branches)
- [100-help-and-entrypoints](#100-help-and-entrypoints)
- [110-hierarchy](#110-hierarchy)
- [120-graph-and-next](#120-graph-and-next)
- [130-notes-and-index](#130-notes-and-index)
- [140-resolve](#140-resolve)
- [150-heading-and-repair](#150-heading-and-repair)
- [160-evidence](#160-evidence)
- [170-evidence-gate](#170-evidence-gate)
- [180-cancel](#180-cancel)
- [190-amend](#190-amend)
- [200-link-removal](#200-link-removal)
- [230-scratch-dir](#230-scratch-dir)
- [240-test-plan-gate](#240-test-plan-gate)
- [250-degrees-of-freedom](#250-degrees-of-freedom)
- [260-owner-words-context](#260-owner-words-context)
- [270-ac-check](#270-ac-check)
- [280-approve-resolves-tools](#280-approve-resolves-tools)
- [290-generated-views-untracked](#290-generated-views-untracked)
- [410-start-branch-id](#410-start-branch-id)
- [The wo defaults](#the-wo-defaults)
- [420-code-dir-checks](#420-code-dir-checks)
- [430-approve-make-wildcard-include](#430-approve-make-wildcard-include)
- [450-code-dir-worktree](#450-code-dir-worktree)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

What each case runs, what it asserts, and **why that failure would matter**.

A case whose "why" cannot be written is a case not worth keeping.
Several of the case files are mostly refusals, because a validator that never rejects anything is not a validator.

Run everything with:

```sh
bash testing/run-tests.sh
```

---

## How the suite runs

Every check runs inside Podman, per root `CLAUDE.md` Rule 14.
There is no threshold below which host execution is acceptable.

| Flag                    | Proves                                                    |
| ----------------------- | --------------------------------------------------------- |
| `--network=none`        | no case reaches the network                               |
| `-v $SKILL:/skill:ro,Z` | no script writes next to itself                           |
| `-v $SCRATCH:/work:Z`   | every output lands where documented                       |
| `--userns=keep-id`      | scratch files are owned by you, not root                  |
| `-e SCAFFOLD_NOW=...`   | the clock is fixed, so determinism is provable with `cmp` |

The suite builds its own image from `testing/Containerfile`, because no stock slim image carries both `jq` and `git`.
The base is pinned by digest per Rule 15; the build needs the network once, and the cases then run with it off.
`gh` is never installed: each case that needs it stubs it with `gh_stub`, because the close-out tests are about what the script does with `gh`'s answer, so that answer has to be under the test's control.

The scratch directory is removed by a trap on every exit path, including failure and Ctrl-C.
After the run, `run-tests.sh` diffs the skill directory's file list against the one it took before, and fails if anything appeared: a script that wrote beside itself is a bug even when every assertion passed.

Totals are computed from the run, never hand-maintained.
Every case ends with `finish`, which prints its totals line and turns a failed check into a non-zero exit; a case without it is invisible to the count and cannot fail the suite.

Assertions live in `testing/assert.sh` and are on exit codes and file contents, never on whether some text appeared somewhere.
A check that passes for the wrong reason is worse than no check, so every helper names what it expected.

---

## 010-new-happy

`new` on the documented happy path, and the determinism the skill claims.
Asserts the index is generated, the frontmatter parses as JSON, the non-goals and the human criterion are rendered, and that the same inputs under the fixed clock produce a byte-identical ticket.
Why: "the script writes the ticket" is only a guarantee if two runs agree to the byte.

## 020-new-refuses

The refusals: a missing title, an unknown type, no `--out`, no home.
Why: a validator that never rejects anything is not a validator, and an empty Out list is what lets an agent wander.

## 030-figma-binding

The frozen block is derived from `build-plan.json`, not hand-written, and `--frames` cuts it down.
Why: with wireframes present the plan leads, and a block typed by a model would be the drift this skill forbids.

## 040-evidence-snapshot

Both wireframe files are snapshotted into `work-orders/evidence/<ID>/`.
Why: figma-wireframe writes fixed filenames into the working directory, so wireframing a second feature would otherwise destroy the first ticket's evidence.

## 050-lifecycle

The status set is closed and every transition is validated; an illegal move is refused by name.
Why: a lifecycle that can be skipped is not a lifecycle.

## 060-approve-blocks

`approve` refuses while a question is open or no criterion exists.
Why: approve is a gate, not a rubber stamp.

## 070-cleanup-refuses-unmerged

`cleanup` asks `gh` whether the PR merged and refuses anything but `MERGED`.
Why: it runs `git branch -D` and `git push --delete`; believing the caller would delete unmerged work.

## 080-cleanup-dry-run

`--dry-run` prints the whole plan, states in words that the command writes nothing, and touches nothing.
Why: the previous version of this command wrote a commit to `main`, and a reader who remembers that needs to be told it no longer does.

## 090-done-archives-on-branch

`done` moves the ticket to the archive on the feature branch and commits nothing.
Why: the archive has to ride the ticket's own pull request; a `done` that committed would put the record on `main` by a second route.

## 095-cleanup-deletes-branches

The happy path against a real bare origin: both branches are gone and `main` gained no commit.
Why: cleanup is not bookkeeping; the archive reached `main` inside the pull request before it ran.

## 100-help-and-entrypoints

Every subcommand at least loads and answers `--help`.
Why: a syntax error in a path the happy path never touches is otherwise found by the first agent that needs that path.

## 110-hierarchy

A child is written under its parent, and re-homing carries grandchildren along.
Why: the layout is the record of the work, so a move that leaves a descendant behind is a lost ticket.

## 120-graph-and-next

Dependencies, cycles in either direction, and what `next` offers.
Why: "may I start this?" is answered by the script, so the cases that matter are the ones where the honest answer is no.

## 130-notes-and-index

Notes are appended newest-first by the tool, and `reindex --check` fails on a drifted index.
Why: a hand-edited note is the failure this skill removes, and an index that disagrees with the tickets misroutes the next agent.

## 140-resolve

`resolve` records an answer and ticks the box, and `approve` is still refused while one question of two is open.
Why: the point of `resolve` was never to loosen the gate.

## 150-heading-and-repair

No `%%` survives a render, an unwired template token refuses the write, and a repaired ticket is byte-identical to a freshly minted one.
Why: the H1 placeholder leaked for 27 tickets because a wrong heading breaks nothing downstream, so the guard is the more important half of the fix.
It is also the model for any case that doctors the template: copy the skill out of its read-only mount, edit the copy, run the copy.

## 160-evidence

`evidence` records an observation and ticks the criterion, and `done` is still refused while one criterion of two is unobserved.
Why: the refusal names the verb that fixes it, because an error that says what is wrong but not what to run is how a hand edit gets invented.

## 170-evidence-gate

`evidence` requires `in-progress` or `in-review`, walked through every status.
Why: a criterion ticked on a draft lets `done` pass having observed nothing, so the gate was load-bearing and open at the same time.

## 180-cancel

`cancel` archives a ticket with a required reason, does no git or `gh` work, and refuses a `done` ticket.
Why: abandoned work otherwise sat in the index forever or was deleted by hand, which takes the reason with it.

## 190-amend

`amend` replaces a section wholesale on a draft, never empties the non-goals, preserves the frozen block, and refuses a ready ticket.
Why: a ticket whose scope can move after approval is not a contract.

## 200-link-removal

`--no-depends-on` and `--no-blocks` remove both halves of an edge, and `--detach --depends-on` is refused rather than guessed at.
Why: a half-edge leaves `next` refusing from one side with nothing on the other side to explain why.

## 230-scratch-dir

The scratch directory outlives the command substitution that asked for a temp file, and is still removed when the shell exits.
Why: the EXIT trap used to fire when `$(ps_tempfile)` closed, deleting the file before the caller could write a byte; the fix must not trade that corruption for a leak.

## 240-test-plan-gate

`start` refuses a `test` ticket whose plan is missing, has no case, has a case missing a field, or is not pinned.
Why: the tester runs exactly the plan the architect wrote, so a plan that cannot be run as written was never the plan anybody approved.

## 250-degrees-of-freedom

Two `--freedom` lines render as `[free]` lines in order between Scope and Acceptance criteria; none renders exactly the one `[fixed]` line; the Contents list equals the body's own H2 headings in order; `repair` and `reindex --check` leave both alone; `amend --freedom` replaces wholesale on a draft, withdraws to the fixed line on `""`, and is refused on a ready ticket with exit 3; an unwired `%%DEGREES_OF_FREEDOM%%` refuses the write.
Why: a ticket that is silent about what the implementer may decide reads as "use your judgement", and a Contents list typed by hand drifts the first time a section is added.
The Contents reference is computed from the rendered body, never typed into the test, so the assertion is that the map agrees with the territory whatever the territory is.

## 260-owner-words-context

`new` without `--owner-words` exits 3 `missing_owner_words`, without `--context` exits 3 `missing_context`, a blank value does not count, and a refused run writes nothing; with both, the Owner words quotes, the Context section and the Contents entry are rendered.
Why: the owner's words and the full context are what stop an idea being lost between design and build (item 30).
Every refusal calls `work-order.sh` directly, because `wo` would supply the defaults whose absence is under test.

## 270-ac-check

An `--ac` with no `--ac-check` exits 3 `missing_ac_check`; a check before any `--ac` is a usage error; `ac_checks` and the `check:` sub-bullet are written; `check` refuses a ready ticket, exits 1 with `AC-FAIL` for a wrong exit code or unmatched output, ticks a pass with command, exit code and output, and `--index` runs one; `done` refuses with `ac_check_failed` while a check fails and closes an all-green ticket; `amend --ac` needs a check.
Why: a box ticked by hand is a claim, not a proof, and a gate that `done` does not enforce is not a gate.

## 280-approve-resolves-tools

`approve` passes when make targets (one reached through `include`), a script and a command resolve, and refuses with exit 3 `tool_missing` naming a missing make target, script, command or AC check command, leaving the ticket `draft`; a target listed under `--provides` passes; a file only in the working tree does not count as on main.
Why: a ready ticket that names a tool which is not on main sends a build seat off to invent it (ORD-0555).

## 290-generated-views-untracked

`next` and `tree` rebuild `INDEX.md` when it is absent, and `reindex --check` passes without it but still fails on a loose top-level ticket.
Why: the generated views are untracked, so a fresh clone has none and two parallel ticket PRs must never conflict on a shared file.

## 410-start-branch-id

Two tickets with the same 60-char title both `start` (exit 0) on different branches, each ending with its own id hex prefix.
Why: the slug is cut to 48 chars, so a shared title prefix gave one branch name and the second `start` refused `branch_exists` (WO-20261016-94e2 against merged WO-20261016-6e55).

## The wo defaults

`assert.sh`'s `wo` adds inert defaults to `new` and `amend`: `--owner-words 'test owner words'` and `--context 'test context'` on `new` when absent, and `--ac-check true --ac-exit 0` after every non-empty `--ac` not already followed by `--ac-check`.
Why: the older cases test other behaviour, so the required flags must not change what they prove.
Cases 150 and 250 call `work-order.sh` directly and so pass the flags themselves; 260 and 270 do too, for every refusal they assert.

## 420-code-dir-checks

`check` and `done` run a cross-repo ticket's checks in `--code-dir`, exit 2 `code_dir_required` without it, and exit 3 `code_dir_mismatch` when the checkout's origin is another repo; a ticket without a repo checks in the project as before.
Why: WO-20261016-2d63 passed in its code worktree but `done` ran in the business tree and failed (WO-20261016-1099).

## 430-approve-make-wildcard-include

`approve` passes a make target defined in a file reached through `-include $(wildcard $(D)mk/*.mk)` where `D` is the including makefile's own directory, and still refuses (exit 3) a target that is not defined.
Why: wiki-process was refused as tool_missing although `make -n wiki-process` exits 0 on main (WO-20261016-0f38).

## 450-code-dir-worktree

`approve`, `check`, `evidence` and `done` on a ticket with a repo run in a detached worktree of `--code-dir` at freshly fetched origin/main, the open PR head, or `--code-ref`; the checkout's working tree is never read, `code_fetch_failed` follows three failed fetches, and no worktree is left behind.
Why: a stale or dirty code checkout passed approve for tools not on main, and done in the wrong tree failed WO-20261016-64f2 (F44, WO-20261016-318d).
