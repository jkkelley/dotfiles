#!/usr/bin/env bash
# Does the folded command reassemble into the SAME argv as the unfolded one?
#
# This does not check my wrapping against my own un-wrapping - that would only
# prove the two agree with each other. It puts a stub `claude` on PATH, runs
# BOTH forms through a real bash, and compares the argv each one actually
# delivered. If the shell disagrees with me, this fails.
set -uo pipefail
HP="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/../scripts/hydration.sh"
PASS=0; FAIL=0
ok()  { printf '  PASS  %s\n' "$1"; PASS=$((PASS+1)); }
bad() { printf '  FAIL  %s\n' "$1"; FAIL=$((FAIL+1)); }

W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
mkdir -p "$W/bin" "$W/proj"

# The stub prints one argument per line, delimited, so a lost or gained space
# inside an argument shows up rather than blending in.
cat > "$W/bin/claude" <<'STUB'
#!/usr/bin/env bash
i=0
for a in "$@"; do printf '[%d]<%s>\n' "$i" "$a"; i=$((i+1)); done
STUB
chmod +x "$W/bin/claude"
export PATH="$W/bin:$PATH"

bash "$HP" init --project "$W/proj" >/dev/null 2>&1
cat > "$W/body.md" <<'BODY'
### Ticket
x
### What just landed
x
### What is NOT done
x
### Stale or false in the docs
x
### Your scope
x
### Before you start
None.
### Read in this order
x
### Reuse, it is proven
x
### The verification ladder
x
### Traps, already paid for
x
### Workflow
x
### Conventions
x
BODY

run_form() {           # run_form <file-with-command>  -> argv dump
  ( cd "$W" && bash "$1" )
}

compare_at() {         # compare_at <label> <width> [--id ID --title T]
  local label=$1 width=$2; shift 2
  bash "$HP" command --project "$W/proj" --width "$width" "$@" > "$W/folded.sh"
  bash "$HP" command --project "$W/proj" --oneline        "$@" > "$W/flat.sh"

  local a b
  a=$(run_form "$W/folded.sh" 2>&1)
  b=$(run_form "$W/flat.sh"   2>&1)

  if [[ $a == "$b" ]]; then
    ok "$label: folded at $width reassembles to identical argv"
  else
    bad "$label: folded at $width produced DIFFERENT argv"
    printf '    folded:\n%s\n    flat:\n%s\n' "$a" "$b"
  fi

  # Folded if and only if it needed to be. The first version of this assertion
  # said "must fold below width 200", which is not the rule and failed on a
  # command that was simply shorter than the width.
  local lines flatlen; lines=$(wc -l < "$W/folded.sh"); flatlen=$(wc -c < "$W/flat.sh")
  flatlen=$(( flatlen - 1 ))                    # drop the trailing newline
  if (( flatlen > width )); then
    (( lines > 1 )) && ok "$label: folded because $flatlen > $width ($lines lines)" \
                    || bad "$label: $flatlen chars exceeds $width but nothing folded"
  else
    (( lines == 1 )) && ok "$label: $flatlen fits in $width, correctly left unfolded" \
                     || bad "$label: folded a command that already fitted"
  fi

  # no line may exceed the width
  local over; over=$(awk -v w="$width" 'length($0) > w {c++} END{print c+0}' "$W/folded.sh")
  [[ $over == 0 ]] && ok "$label: no line exceeds $width columns" \
                   || bad "$label: $over line(s) exceed $width columns"

  # continuations start at column 0
  local indented; indented=$(awk 'NR>1 && /^[[:space:]]/ {c++} END{print c+0}' "$W/folded.sh")
  [[ $indented == 0 ]] && ok "$label: continuations are flush left" \
                       || bad "$label: $indented continuation line(s) are indented"
}

echo "=== ticketless entry"
bash "$HP" add --project "$W/proj" --title "Design pass" --body-file "$W/body.md" >/dev/null 2>&1
for w in 40 55 68 80 120 250; do compare_at "ticketless" "$w"; done

echo
echo "=== ticketed entry, long title"
bash "$HP" add --project "$W/proj" --id WO-20260818-7a0b \
  --title "CI/CD + GitOps: Jenkins pipeline, ghcr, chart, Vault, ArgoCD" \
  --body-file "$W/body.md" >/dev/null 2>&1
for w in 40 55 68 80 120 250; do compare_at "ticketed" "$w"; done

echo
echo "=== the apostrophe, which is the one that would bite"
# "you've" sits inside the double-quoted prompt. If a fold ever landed such that
# the shell saw it unquoted, this is where it would blow up.
bash "$HP" command --project "$W/proj" --width 44 > "$W/ap.sh"
if run_form "$W/ap.sh" >/dev/null 2>&1; then
  ok "an apostrophe inside the folded prompt does not break the parse"
else
  bad "an apostrophe inside the folded prompt broke the parse"
  run_form "$W/ap.sh" 2>&1 | head -3
fi

echo
echo "=== the argument really is one argument, not several"
COUNT=$(run_form "$W/ap.sh" | grep -c '^\[')
FLATCOUNT=$(bash "$HP" command --project "$W/proj" --oneline > "$W/f2.sh"; run_form "$W/f2.sh" | grep -c '^\[')
[[ $COUNT == "$FLATCOUNT" ]] && ok "same argument count folded and flat ($COUNT)" \
                             || bad "folded gave $COUNT arguments, flat gave $FLATCOUNT"

echo
printf 'Result: %s passed, %s failed\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]] || exit 1
