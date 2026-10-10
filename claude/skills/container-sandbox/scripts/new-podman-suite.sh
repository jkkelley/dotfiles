#!/usr/bin/env bash
# new-podman-suite.sh - scaffold a Podman test suite for a tool from templates,
# and render its test-plan block, so nobody hand-writes a harness again.
#
#   new-podman-suite.sh --target <tool-dir> --name <name> [--image localhost/<name>-test:1]
#                       [--config <basename>] [--apt "<extra debian packages>"] [--force]
#   new-podman-suite.sh --target <tool-dir> --name <name> --test-plan     # print the plan block only
#
# Writes <tool-dir>/tests/{Containerfile,run-tests.sh,inside.sh,probe.mjs} from
# references/templates/podman-suite/. Existing files are refused unless --force.
# --test-plan prints a block in the claude/workflow/templates/test-plan.md shape,
# ready for `work-order.sh new --test-plan-file`.
# Exit codes: 0 ok, 2 usage, 3 refused (file exists), 4 io.
set -euo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd); T="$HERE/../references/templates/podman-suite"
die() { local c=$1; shift; printf 'new-podman-suite: %s\n' "$*" >&2; exit "$c"; }
TARGET=""; NAME=""; IMAGE=""; CONFIG=""; APT=""; FORCE=0; PLAN=0
while [ $# -gt 0 ]; do case $1 in
  --target) TARGET=$2; shift 2;; --name) NAME=$2; shift 2;; --image) IMAGE=$2; shift 2;; --config) CONFIG=$2; shift 2;;
  --apt) APT=$2; shift 2;; --force) FORCE=1; shift;; --test-plan) PLAN=1; shift;; -h|--help) sed -n '2,14p' "$0" >&2; exit 0;; *) die 2 "unknown flag $1";; esac; done
[ -n "$TARGET" ] && [ -n "$NAME" ] || die 2 "--target and --name are required"
[[ $NAME =~ ^[a-z][a-z0-9-]{0,31}$ ]] || die 2 "--name must be ^[a-z][a-z0-9-]{0,31}$"
[ -z "$IMAGE" ] && IMAGE="localhost/$NAME-test:1"; [ -z "$CONFIG" ] && CONFIG="$NAME"
[ -d "$T" ] || die 4 "templates missing at $T"
DIGEST=$(grep -o 'sha256:[0-9a-f]\{64\}' "$T/Containerfile.tmpl" | head -1); TAG=$(grep -o 'Human tag: [^ ]*' "$T/Containerfile.tmpl" | cut -d' ' -f3)
if [ "$PLAN" = 1 ]; then
  cat <<PLAN
_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

$NAME: the suite under $TARGET/tests, one case per \`check\` in inside.sh

**Cases**

- \`TP-1\`
  - intent: a config or script change that breaks $NAME is caught before the PR, not by the owner
  - command: \`make -C $TARGET test\`
  - expected: exit 0 and the line \`$NAME tests: N passed, 0 failed\`

**Isolation**

- runtime: podman
- image: \`mcr.microsoft.com/playwright@$DIGEST\` ($TAG)

**Out of scope - CI covers**

- the full repo pipeline; this plan is the tool's own suite
PLAN
  exit 0
fi
mkdir -p "$TARGET/tests"
render() { sed -e "s#__NAME__#$NAME#g; s#__IMAGE__#$IMAGE#g; s#__CONFIG__#$CONFIG#g; s#__APT_EXTRA__#$APT#g" "$T/$1.tmpl"; }
for f in Containerfile run-tests.sh inside.sh probe.mjs; do
  out="$TARGET/tests/$f"
  [ -e "$out" ] && [ "$FORCE" = 0 ] && die 3 "$out exists; pass --force to overwrite"
  render "$f" > "$out.tmp" && mv "$out.tmp" "$out"
  case $f in *.sh) chmod +x "$out";; esac
done
printf '%s\n' "$TARGET/tests"
