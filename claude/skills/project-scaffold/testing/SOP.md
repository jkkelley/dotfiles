# Testing SOP

What each case runs, what it asserts, and **why that failure would matter**.

A case whose "why" cannot be written is a case not worth keeping.
Three of the sixteen case files are mostly negative tests, because a validator that never rejects anything is not a validator.

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

The cases run under **bash**, not `sh`.
Every image's `/bin/sh` here is dash, which has no arrays, no `[[ ]]`, no `mapfile` and no `PIPESTATUS`.
A suite that ran under dash would fail for reasons that have nothing to do with the code being tested.

### Two images, and why

`run-tests.sh` runs `testing/cases/` and `testing/cases-git/` in turn, under different images, and sums the totals.

| Directory    | Image                    | Needs                                                                        |
| ------------ | ------------------------ | ---------------------------------------------------------------------------- |
| `cases/`     | `python:3.12-slim`       | `python3`, to assert the generated settings JSON actually parses             |
| `cases-git/` | `bitnami/git`, by digest | a real `git`, to assert the gitignore blanket by asking git rather than grep |

No stock image carries both, and installing one into the other means a network fetch inside a suite that runs `--network=none` on purpose.
So there are two runs.

The split is not filing: a case belongs in `cases-git/` when the thing it asserts is git's behaviour and not the template's text.
Grepping `gitignore.tmpl` for a line proves the line is there; it does not prove git honours it, and a `**/` pattern that behaved differently from the one beside it would leave the grep green and the property false.

The git image ships **no `cmp`**, so `assert_same` hashes when `cmp` is absent.
`cmp` missing exits 127, which is indistinguishable from "the files differ" and is the more misleading of the two.
Anything else added to `cases-git/` should check for a utility before depending on it, per root `CLAUDE.md` Rule 17.

`SCAFFOLD_NOW` exists solely for this suite.
Without an injectable clock, "same input produces the same output" cannot be asserted - only eyeballed, which proves nothing.

---

## 010-scaffold-fresh

**Runs:** a dry run then an apply against an empty directory.

**Asserts:** the dry run writes nothing; apply creates all five markdown files, `.claude/settings.json`, `.claude/skills.toml` and the vendored scripts, and creates **no** `.claude/scaffold.json`; `ISSUES.md` carries its sentinel; `CLAUDE.md` carries the `CONTEXT_STATE.md` pointer.

The negative assertion is the one that earns its keep. `scaffold.json` was removed rather than emptied, and a file nobody writes is not something a test notices - it just stops appearing, and reappears the moment someone restores the block that wrote it.

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
There is no longer an exclusion. `scaffold.json` used to be one - it recorded a build timestamp by design, so a second apply legitimately changed it - and the claim had a documented hole in it. `scaffold.sh` writes no timestamp anywhere now, so the hash covers every file and the missing `! -name` is the proof.

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

**Asserts:** the copy matches on install; a tampered copy is reported as `refresh` and not `skip`; apply re-syncs it; the vendored script actually runs from inside the project.

The `scaffold.json` assertion is gone with the file. It was never the mechanism anyway - `refresh` is decided by comparing the copy against the skill, and a stamp saying which tool version wrote it answers nothing about a copy that has since been edited.

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

## 120-ignore-files

**Runs:** a plain scaffold, a scaffold with `--no-gitignore`, then a re-apply over hand-edited ignore files.

**Asserts:** `.gitignore` and `.dockerignore` are created with no flag at all; each matches its template byte for byte; the upstream rules arrived (`**/node_modules/`, `!**/.env.example`, `**/.git/`); the scaffold's own entries survived the vendoring (`.claude/cache/`, `.claude/settings.local.json`, both lock files); provenance is recorded with a `<your-github-username>` placeholder; `--no-gitignore` suppresses one without suppressing the other; hand-edited copies survive a re-run.

**Why it matters:** these two files come from an upstream repo, so their exact text is _expected_ to change.
Asserting the text would only produce a test that has to be edited on every re-pull, which trains people to edit tests rather than read them.
What must not change is the pair of properties around the copy: the project's copy is byte-identical to the template, and the scaffold's own entries are still in it.
A re-pull that quietly dropped `.claude/cache/` would start committing derived state to every project this skill has ever touched, and nothing would fail - the repository would just get slowly wrong.

The byte-for-byte assertion is also what makes drift visible: if someone hand-edits a project's `.gitignore` instead of the template, the next comparison says so.

---

## 130-backlog-read-window

**Runs:** a scaffold, then inspects `CLAUDE.md`, `COMPASS.md` and `BACKLOG.md` for the read-depth rule.

**Asserts:** all three state the 10-entry window for `BACKLOG.md`; two of them scope it explicitly to the `Done` bucket; `Now` / `Next` / `Later` are stated as read-in-full; the 20-item retention limit is still documented alongside the 10-item read window.

**Why it matters:** a read-depth rule is only load-bearing where the agent actually looks.
An agent that opens `BACKLOG.md` directly, without reading `CLAUDE.md` first, has to meet the rule in the file itself - which is why it is stated in three places and why all three are asserted.
Drop it from any one of them and the default silently reverts to reading all 20 `Done` entries. Nothing fails; the cost just shows up as tokens.

The retention assertion guards the other direction. `Done` keeps 20 but is read 10 deep, and two nearby numbers that differ look like a bug to the next reader - the file has to say why, or someone will "fix" one to match the other and destroy either the window or the lookup.

---

## 140-skill-version-check

**Runs:** a scaffold, then inspects `CLAUDE.md` for the session-start skill version check.

**Asserts:** the section is present; the registry URL is carried literally, owner and all; it has not been rewritten into an angle-bracket placeholder; the check reads the installed `version:` lines as well as the registry; both apply modes are offered; the happy path is silent; an unreachable registry does not block the session; and the whole check is skipped where `.claude/skills/` does not exist.

**Why it matters:** skills are installed into a project as copies, and a copy cannot know the original moved on.
This section is the only thing that ever raises the question.
Drop it from the template and every project scaffolded from then on runs on whatever skill version it was born with, indefinitely - and nothing fails, because old skills still work.
That is exactly how two existing projects ended up without the check and stayed that way until somebody asked.

The URL assertion is the sharp one, and it guards against this repository's own house style.
Root `CLAUDE.md` requires environment-specific values to become `<angle-bracket>` placeholders, and this URL is its single documented exception.
Substituting the owner points the check at a repository that does not exist, so the fetch fails, the check reports `registry unreachable`, and the session starts anyway.
It breaks silently and stays broken, which is why a literal-string assertion sits in front of it.

The silence assertion guards the opposite failure. A check that announces itself every session becomes noise, and noise gets skipped.

---

## 150-runbooks-source-of-truth

**Runs:** a scaffold, then inspects `CLAUDE.md` for the rule naming the one repository that holds every runbook and playbook.

**Asserts:** the section is present; the `local-k8s-docs` URL is carried literally, owner and all; it has not been rewritten into an angle-bracket placeholder; runbooks and playbooks are both named; a missing grant is something to ask for rather than route around; a new document follows the format of the ones beside it; working a process out obliges you to write it down; and a documented process beats a locally invented one.

**Why it matters:** an agent that has never been told the documentation exists does the reasonable thing and invents a procedure.
Inventing it never feels like authoring a runbook - it feels like finishing the task - so it is never written down.
The knowledge then lives in a session transcript nobody opens again, and the next agent invents a different procedure for the same job.
Nothing fails at any point. The setup just quietly accumulates N procedures where it should have one, and each is discovered only when it contradicts another.

The URL assertion is sharp for the same reason case 140's is, and guards against this repository's own house style.
Root `CLAUDE.md` requires environment-specific values to become `<angle-bracket>` placeholders, and this URL is a second documented exception to that.
Substituting the owner turns the single pointer to the documentation into a link to a repository that does not exist.
Nothing catches that: an agent that cannot find the repository concludes there is nothing in it and goes back to inventing.

The last two assertions are deliberately separate rather than one combined check.
"Write the missing one" and "do not invent a parallel one" are opposite failures - the first leaves a gap, the second fills it twice - and a template could easily keep one sentence while losing the other.

---

## 160-skills-manifest

**Runs:** a scaffold, then inspects `.claude/skills.toml`, then re-applies over a hand-edited one, then reads the plan for both an existing and an absent manifest.

**Asserts:** the file is created and is byte-identical to the template; all four of decision 20's skills are named individually; the `[skills]` and `[agents]` headers and the `use = [` form are present; no version appears anywhere; a hand-edited manifest survives a re-apply untouched; the plan says `skip` for an existing manifest and `create` for an absent one, and the dry run still writes nothing.

**Why it matters:** the manifest is the project's declared intent and `skill-sync` acts on it without asking.
A re-apply that clobbered it would delete a skill someone added, and the next session start would then delete that skill's directory - so the damage arrives one step removed from the thing that caused it, on a different day, and looks like the sync malfunctioning.

The four names are asserted one at a time rather than counted. "Four skills are declared" stays green if one is swapped for another, and the four are not interchangeable: `CLAUDE.md.tmpl` references `work-order` in six places, so a manifest without it ships a template pointing at a script that was never installed.

The version assertion is the negative half of that.
`skill-sync` pulls fresh copies at every session start, so a version written here has no effect on what gets installed and is simply a claim - wrong within a week, and believed by the next agent that reads it.

The section-header assertions guard a silent failure specific to this format.
`skill-sync`'s parser reads exactly one shape, and a manifest whose sections are named differently parses to an empty list rather than an error, because an empty manifest is a legal manifest.

---

## cases-git/010-skills-gitignored

**Runs:** a scaffold, `git init`, a managed skill and a hand-authored one written under `.claude/skills/`, then `git check-ignore` on each path and a `git add -A` to see what actually reaches the index.

**Asserts:** every path under `.claude/skills/` is ignored, hand-authored included; `.claude/skills.toml`, `.claude/settings.json`, `.claude/scripts/log-issue.sh` and `CLAUDE.md` are **not** ignored; after `git add -A` nothing under `.claude/skills/` is staged and the manifest is.

**Why it matters:** this is the acceptance criterion of the change, asserted in the sentence it was written in.
A committed skill copy is worse than no copy: it never updates again, `registry.json` moves on without it, and the divergence is invisible because a project's copy is _expected_ to differ from upstream, so the content hash cannot catch it either.

The positive and the negative are on the same tree in the same run on purpose.
A blanket that swallowed `.claude/skills.toml` along with the copies would take the project's declared intent out of git, and nothing would surface it until someone cloned the repository and got a project that syncs nothing.

Note what the positive assertion also proves: a hand-authored skill under `.claude/skills/` cannot be committed either.
That is the price of a blanket and it is deliberate - the alternative is a per-name exception list that has to be maintained in two places and is wrong the moment it is not.

The `git add -A` check is not redundant with `check-ignore`.
`check-ignore` answers per path; the index answers "what would actually be committed", which is what the criterion claims.

---

## Adding a case

1. Add `testing/cases/NNN-name.sh`, sourcing `testing/assert.sh`.
   If what it asserts is git's behaviour rather than a file's contents, it goes in `testing/cases-git/` instead - and must not depend on `cmp`, which that image does not ship.
2. Use `new_project` or `scaffolded_project` - never share state between cases.
3. Assert on exit codes and file contents, never on whether some text appeared somewhere.
4. Add a section here with all three parts, including the why.

If a check cannot run - no Podman, no image, a dependency the sandbox cannot provide - say which check was skipped and why.
Per root `CLAUDE.md` Rule 12, reporting the subset that passed as "tested" is wrong.
