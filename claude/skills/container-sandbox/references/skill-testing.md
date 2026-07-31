# Testing skills and their bundled scripts

This is the reference for testing the executable parts of a skill or agent in this repo.
It exists because the main `SKILL.md` covers npm, Terraform, Kind, and full-stack compose, but not the plain-script case: a skill that ships a few Python or Bash files and claims they do something.

**Every command that verifies a skill runs inside Podman. No exceptions, including a one-line `python3 --version`.**

Running a skill's script on the host is how you end up shipping a script that only works on your machine, silently depends on a package you happen to have installed, or writes files where you did not expect.
The container is not ceremony. It is the only way the claim "this works" means anything to the next person who clones the repo.

---

## The invocation pattern

Three properties make a skill test trustworthy.
Each maps to one flag.

| Property                                  | Flag                               | What it proves                                    |
| ----------------------------------------- | ---------------------------------- | ------------------------------------------------- |
| The script does not reach the network     | `--network=none`                   | A "stdlib only, no pip installs" claim is real    |
| The script does not mutate its own source | `-v .:/skill:ro,Z`                 | Reruns are clean; the skill is not self-modifying |
| Outputs land where documented             | separate writable `-v ...:/work:Z` | No stray files in the skill directory             |

Plus `--userns=keep-id` so anything written to the mounted scratch directory is owned by you, not root.

```bash
podman run --rm --userns=keep-id --network=none \
  -v "$PWD:/skill:ro,Z" \
  -v "$SCRATCH:/work:Z" \
  -w /work \
  docker.io/library/python:3.12-slim \
  sh -c '<test commands>'
```

Pick the smallest image that matches the skill's declared floor.
A skill that says "Python 3.9+" is tested on `python:3.12-slim`, not on whatever the host has.
Reuse an image already present in `podman images` before pulling a new one.

---

## What "tested" means for a skill

A skill's scripts are tested when all four of these have run in the container and passed.
Three of the four are about failure, because a validator that never rejects anything is not a validator.

1. **Happy path exits 0.** Feed it the example input from the skill's own documentation. If the docs contain an example that the script rejects, the docs are wrong and that is a finding.
2. **Bad input exits non-zero.** Hand it something structurally invalid and assert the exit code is not 0. Assert on the exit code, not on whether error text appeared.
3. **Determinism, where the skill claims it.** Run the same input twice into two output files and `cmp` them. If a skill's whole value proposition is "same input, same output", an untested claim is a marketing line.
4. **Every entry point at least loads.** `--help` on each script catches import errors and syntax errors in files the happy path never touched.

---

## Good and bad examples

### Exit codes

The most common way a skill test lies is by not checking the exit code at all.

**Bad.** The pipe swallows the exit code, so this passes whether the validator returned 0 or 1:

```bash
python3 validate_brief.py bad.json | tail -3
```

**Bad.** `$PIPESTATUS` is a bashism. The `sh` in `python:3.12-slim` is dash, and this prints `Bad substitution` and aborts the run:

```bash
python3 validate_brief.py bad.json | tail -3; echo "exit=${PIPESTATUS[0]}"
```

**Good.** Redirect the noise, capture the code, state the expectation inline so a wrong result is obvious in the log:

```bash
python3 validate_brief.py bad.json >/dev/null 2>&1
echo "negative-test exit=$?  (want 1)"
```

If you need bash features, ask for bash explicitly: `podman run ... bash -c '...'` on an image that has it.
Do not assume `sh` is bash.

### Negative tests

**Bad.** Asserts that the script failed, but not that it failed for the right reason. A typo in the filename produces the same "pass":

```bash
python3 validate_brief.py bad.json && echo FAIL || echo "rejected, good"
```

**Good.** Assert the exit code and that the specific rule fired:

```bash
python3 validate_brief.py bad.json >out.txt 2>&1
echo "exit=$?  (want 1)"
grep -q "scope 'backend' produces a diagram" out.txt && echo "correct rule fired"
```

### Determinism

**Bad.** Eyeballing two runs proves nothing about the bytes:

```bash
python3 plan.py brief.json --out p1.json
python3 plan.py brief.json --out p2.json
echo "looks the same"
```

**Good.** `cmp` fails loudly and returns non-zero:

```bash
python3 plan.py brief.json --out p1.json >/dev/null
python3 plan.py brief.json --out p2.json >/dev/null
cmp p1.json p2.json && echo "byte-identical OK"
```

### Test fixtures

**Bad.** A hand-written fixture that drifts from the documented example. It tests a shape no user will ever supply:

```bash
echo '{"project":"x","scope":"frontend"}' > brief.json
```

**Good.** Extract the fixture from the skill's own documentation, so the test fails when the docs go stale:

````bash
python3 - <<'PY'
import json, re
src = open("/skill/references/intake-questions.md").read()
block = re.search(r"```json\n(.*?)```", src, re.S).group(1)
json.dump(json.loads(block), open("brief.json", "w"), indent=2)
PY
````

### Where output goes

**Bad.** Writes into the skill directory, leaving untracked junk that can get committed:

```bash
podman run --rm -v "$PWD:/skill:Z" -w /skill <image> sh -c 'python3 scripts/plan.py brief.json --out build-plan.json'
```

**Good.** Skill mounted read-only, outputs forced into a scratch mount. A script that tries to write next to itself fails here, which is the point:

```bash
podman run --rm --userns=keep-id -v "$PWD:/skill:ro,Z" -v "$SCRATCH:/work:Z" -w /work <image> \
  sh -c 'python3 /skill/scripts/plan.py brief.json --out build-plan.json'
```

---

## Skills with no executable code

A skill that is only Markdown still gets a check, and it still runs in the container.
Verify that every bundled resource the `SKILL.md` references actually exists, since a reference to a deleted file is the most common rot in a docs-only skill:

```bash
podman run --rm --network=none -v "$PWD:/skill:ro,Z" -w /skill \
  docker.io/library/python:3.12-slim \
  python3 -c '
import pathlib, re, sys
root = pathlib.Path("/skill")
text = (root / "SKILL.md").read_text()
refs = set(re.findall(r"(?:references|scripts)/[\w.-]+", text))
missing = sorted(r for r in refs if not (root / r).exists())
print(f"checked {len(refs)} bundled refs; missing:", missing or "none")
sys.exit(1 if missing else 0)
'
```

Match only the bundled `references/` and `scripts/` prefixes.
A broader regex over every path-shaped string also matches files the skill instructs the _user_ to create in _their_ project, such as `test/init.py`, and reports them as missing on every run.
A check that cries wolf gets ignored, which is worse than no check.

---

## Reporting

Report what actually ran, in the container, with real exit codes.
Per root `CLAUDE.md` Rule 12, "tested" is wrong if any check was skipped.
If a check could not run - no image, no Podman, a dependency the sandbox cannot provide - say which check was skipped and why, rather than quietly reporting the subset that passed.
