# Testing SOP

What each case runs, what it asserts, and **why that failure would matter**.

A case whose "why" cannot be written is a case not worth keeping.
Three of the eleven case files are mostly negative tests, because a validator that never rejects anything is not a validator.

Run everything with:

```sh
testing/run-tests.sh
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

The scratch directory is removed by a trap on every exit path, including failure and Ctrl-C.
Nothing the suite creates outlives it.

The image is `python:3.12-slim` and the cases run under **bash**, not `sh`.
It is Debian-based with the same bash 5.2 and coreutils as `debian:stable-slim`, plus a `python3` used only to assert that generated JSON actually parses - a settings file that does not parse is silently ignored by the harness, which is the worst kind of broken.
The image's `/bin/sh` is dash, which has no arrays, no `[[ ]]`, no `mapfile` and no `PIPESTATUS`.
A suite that ran under dash would fail for reasons that have nothing to do with the code being tested.

`SCAFFOLD_NOW` exists solely for this suite.
Without an injectable clock, "same input produces the same output" cannot be asserted - only eyeballed, which proves nothing.

---

## 010-scaffold-fresh

**Runs:** a dry run then an apply against an empty directory.

**Asserts:** the dry run writes nothing; apply creates all five markdown files, `.claude/settings.json`, the vendored scripts, and `.claude/scaffold.json`; `ISSUES.md` carries its sentinel; `CLAUDE.md` carries the `CONTEXT_STATE.md` pointer.

**Why it matters:** dry-run-by-default is the safety property that makes this tool safe to point at an existing project.
A dry run that wrote anything would make every later "it is non-destructive" claim false.
The pointer assertion catches the `context-compaction` integration silently regressing - a missing pointer means that skill's state file is never found.

---

## 020-scaffold-existing

**Runs:** apply against three shapes of pre-existing file - zero bytes, hand-written prose with no structure, and a partially-populated template.

**Asserts:** empty files gain their sections; the unstructured file is left byte-identical; the partial file gains only what it lacks, each section exactly once.

**Why it matters:** this is the entire no-clobber promise, and each shape fails differently.

The zero-byte case is not hypothetical - it is the state this skill's own project was in when the standards were written.
A tool that treated "exists" as "leave alone" would have silently done nothing there.

The unstructured case is the dangerous one: guessing an insertion point in a file someone hand-wrote is how work gets destroyed.
Refusing is the correct behaviour, and `assert_same` against a pre-run copy is the only assertion that proves it.

The partial case catches double-appending, which would quietly duplicate sections on every run.

---

## 030-scaffold-idempotent

**Runs:** apply twice against an already-scaffolded project, hashing every file before and after.

**Asserts:** the second run changes nothing, byte for byte.

**Why it matters:** idempotency is the claim that makes it safe to re-run after adding a section to a template.
Untested, it is a slogan.
`scaffold.json` is excluded because it records a build timestamp by design - excluding it is a deliberate, documented exception rather than a convenient one.

---

## 040-log-issue-happy

**Runs:** two issues, a resolving entry, and a write into a project with no `ISSUES.md` yet.

**Asserts:** IDs increment; the newest entry is the first heading in the file; the resolution is recorded; the original entry is not rewritten; a missing file is created from the template with its sentinel intact.

**Why it matters:** newest-first ordering is what makes the 10-entry window meaningful - if ordering regressed, the window would show the _oldest_ ten and every agent reading it would be misled.
"Original not rewritten" is the append-only guarantee stated as an assertion.

---

## 050-log-issue-reject

**Runs:** every rejection path, plus `--help` on all four entry points.

**Asserts:** missing and empty required values exit 2; a bad severity exits 3; an unknown flag exits 2; an unresolvable `--resolves` exits 6; a malformed ID exits 2; a file with no sentinel exits 3 and is left untouched; a read-only directory exits 4.

**Why it matters:** each assertion is on the exit code, not on whether error text appeared, because a typo in a filename produces the same "it failed" as a correctly-fired rule.
The untouched-file assertions matter most: a rejected write that had already modified the file would be worse than no validation at all.

The `--help` checks are not filler.
They caught a real bug: `backlog.sh` and `cache.sh` take a subcommand as `$1`, so `--help` was consumed as a command name and reported as unknown.
`--help` reaches code paths the happy path never touches, which is exactly where syntax errors hide.

---

## 060-log-issue-concurrent

**Runs:** eight simultaneous writers against one `ISSUES.md`.

**Asserts:** all eight entries land, all eight IDs are distinct, and the sequence has no gaps.

**Why it matters:** parallel agents are normal, not exotic.
Two writers reading "highest is 41" at the same moment would both write `ISS-0042`, and one entry would be silently lost.
Silent data loss is the worst failure this tool could have, so it gets the most direct test.

The no-gaps assertion is the subtler one: a gap means an ID was allocated and its write then lost, which a distinctness check alone would not catch.

---

## 070-backlog-lifecycle

**Runs:** add, move, done, list, plus every refusal.

**Asserts:** IDs increment across buckets; a move preserves `why` and `done-when` exactly; moving to the current bucket is a reported no-op; `done` flips the checkbox and records `completed:` in the metadata rather than in the title; unknown IDs exit 6, unknown buckets exit 3, malformed IDs and unknown subcommands exit 2; a duplicated ID exits 3.

**Why it matters:** `move` is the one operation that rewrites existing content, so byte-preservation of the item body is its core guarantee - anything less means a move quietly edits your text.

The title assertion exists because an earlier implementation appended the completion date to the heading, which leaked the date into every JSON parse of the item's name.

The duplicate-ID case is about refusing to guess.
Two items with one ID is a file a human broke; picking one and proceeding would compound it.

---

## 080-encoding-and-injection

**Runs:** text that fights back - shell metacharacters, a literal `-->`, multi-line values, CRLF line endings, a file with no trailing newline, and a path containing spaces.

**Asserts:** `$(id)` and backticks are written literally and nothing is executed; `-->` becomes `--&gt;` and _not_ `---->gt;`; every metadata block stays balanced; multi-line values collapse to one line; a CRLF file still matches its sentinel; an appended section is not glued to an unterminated last line; a path with spaces works.

**Why it matters:** an issue title is attacker-adjacent input in the only sense that matters here - it is arbitrary text that an agent pastes in without thinking.
If it were ever evaluated, logging an issue would execute it.

The `---->gt;` assertion is a regression test for a real bug found while building this: bash 5.2 expands a bare `&` in a `${var//pat/repl}` replacement to the matched text, so the escape silently corrupted itself.
Nothing about that is obvious from reading the code, which is precisely why it is pinned by a test.

CRLF matters because a file touched once on Windows would otherwise stop matching its own sentinel and be refused forever.
The trailing-newline case prevents corrupting the last record in a file.

---

## 090-cache-freshness

**Runs:** build, verify, mutate a source, verify again, tamper with a recorded hash, delete the cache entirely and rebuild.

**Asserts:** all six slices are produced; verify passes immediately after a build; a resolved issue is absent from `open-issues.json` and an unresolved one is present; mutating a source makes verify exit 3 and name the stale file; a tampered hash reports stale rather than crashing; a deleted cache rebuilds cleanly.

**Why it matters:** a cache trusted while stale is worse than no cache, because it turns a speed optimisation into a source of confidently wrong answers.
Detection is the whole product.

The open-issues assertions test the one thing the cache _computes_ rather than reshapes.
If that logic inverted, an agent would be told a fixed bug is live, or worse, that a live bug is fixed.

The delete-and-rebuild case enforces "derived, never authoritative" - if anything were only stored in the cache, this case would lose it.

---

## 100-version-skew

**Runs:** compares the vendored copies against the skill, tampers with one, re-runs the plan, re-syncs, then executes the vendored copy in place.

**Asserts:** the copy matches on install; `scaffold.json` records the tool version; a tampered copy is reported as `refresh` and not `skip`; apply re-syncs it; the vendored script actually runs from inside the project.

**Why it matters:** vendoring only works if drift is visible.
A silently stale copy would keep writing yesterday's format into today's file, and the whole "change the script, change the format everywhere" property would quietly stop being true.

The run-in-place check is the point of vendoring at all: the project must work for someone who does not have these dotfiles installed.

---

## 110-settings-files

**Runs:** a scaffold, then inspects both `.claude` settings files, then re-applies over a hand-edited one.

**Asserts:** both files are created; `settings.local.json` matches its template byte for byte; neither contains a `/home/` or `/Users/` path; both parse as JSON; a hand-edited settings file survives a re-run untouched.

**Why it matters:** the permission list is deliberately **project-scoped**.
User-level entries such as a home-directory read glob would be wrong in two ways at once: incorrect on any other machine, and a username committed to a public repository.
The two path assertions are the PII rule expressed as a test rather than a promise.

The parse checks exist because a settings file that does not parse is **silently ignored** by the harness.
It fails by doing nothing, which is the worst kind of broken - there is no error to notice.

---

## Adding a case

1. Add `testing/cases/NNN-name.sh`, sourcing `testing/assert.sh`.
2. Use `new_project` or `scaffolded_project` - never share state between cases.
3. Assert on exit codes and file contents, never on whether some text appeared somewhere.
4. Add a section here with all three parts, including the why.

If a check cannot run - no Podman, no image, a dependency the sandbox cannot provide - say which check was skipped and why.
Per root `CLAUDE.md` Rule 12, reporting the subset that passed as "tested" is wrong.
