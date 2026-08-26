#!/usr/bin/env bash
#
# run-tests.sh - the suite for workflows/credential-rotation/.
#
# Everything runs inside Podman, per root CLAUDE.md Rule 14, which has no size
# threshold.
#
#   --network=none      no check reaches the network, which is also how the
#                       suite proves the driver never really calls AWS
#   /repo mounted ro    the driver cannot write next to itself
#   /work separate      every output lands in a scratch mount
#   --userns=keep-id    files in that mount are owned by you, not by root
#
# THE IMAGE IS tools/testing/Containerfile, DELIBERATELY
#
# It is already bash and coreutils on a digest-pinned debian, which is exactly
# what this driver needs. A second Containerfile would mean a second pinned
# digest to repin under Rule 15, and two images that must be kept the same is a
# maintenance cost with nothing bought for it.
#
# WHAT THIS SUITE DOES NOT COVER, STATED PLAINLY
#
# `aws` and `kubectl` are stubs. That makes the driver's own logic - manifest
# parsing, the timestamp arithmetic, the fan-out match, every refusal - fully
# testable offline, and it is the only way to assert the thing that matters
# most: that no code path ever calls get-parameter. It does NOT exercise the
# go-template that turns real ExternalSecrets into the rows the stub hands back.
# That template is verified against the live cluster and the observation is
# recorded on the ticket. A stub cannot prove a template renders.
set -uo pipefail

HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
WF_DIR=$(cd "$HERE/.." && pwd)
REPO_ROOT=$(cd "$WF_DIR/../.." && pwd)
IMAGE="${TOOLS_TEST_IMAGE:-localhost/dotfiles-tools-test:1}"

if [[ ${IN_CREDROT_CONTAINER:-0} != 1 ]]; then
  command -v podman >/dev/null 2>&1 || {
    printf 'podman is required: every check in this suite runs in a container.\n' >&2
    printf 'Running these on the host would prove only that they work on this machine.\n' >&2
    exit 1
  }
  if ! podman image exists "$IMAGE"; then
    printf 'building %s (needs network; the checks run with --network=none)\n' "$IMAGE"
    podman build -t "$IMAGE" -f "$REPO_ROOT/tools/testing/Containerfile" \
      "$REPO_ROOT/tools/testing" >/dev/null || {
      printf 'image build failed\n' >&2; exit 1; }
  fi
  SCRATCH=$(mktemp -d "${TMPDIR:-/tmp}/credrot-test.XXXXXX")
  trap 'rm -rf -- "$SCRATCH"' EXIT INT TERM
  exec podman run --rm --userns=keep-id --network=none \
    -v "$REPO_ROOT:/repo:ro,Z" -v "$SCRATCH:/work:Z" -w /work \
    -e IN_CREDROT_CONTAINER=1 --entrypoint="" \
    "$IMAGE" bash /repo/workflows/credential-rotation/testing/run-tests.sh
fi

# ── inside the container from here ─────────────────────────────────────────────
WORK=${WORK:-/work}
SRC=/repo/workflows/credential-rotation
PASS=0
FAIL=0

ok()  { printf '  PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
bad() { printf '  FAIL  %s\n' "$1"; FAIL=$((FAIL + 1)); }
hd()  { printf '\n=== %s\n' "$1"; }
check() { if [[ $2 -eq 0 ]]; then ok "$1"; else bad "$1"; fi; }
neg() { if "$@" >/dev/null 2>&1; then echo 1; else echo 0; fi; }

expect_rc() { # desc want cmd...
  local desc=$1 want=$2 got
  shift 2
  "$@" >/dev/null 2>&1
  got=$?
  if [[ $got -eq $want ]]; then ok "$desc (exit $got)"; else bad "$desc (exit $got, want $want)"; fi
}

# Copied out of the read-only mount so nothing runs from a path a check could
# write to, and so a driver that tried to write beside itself would fail here.
mkdir -p "$WORK/bin" "$WORK/fixtures" "$WORK/stub"
cp "$SRC/credential-rotation.sh" "$WORK/bin/"
cp "$SRC/credentials.tsv" "$WORK/fixtures/"
CR="$WORK/bin/credential-rotation.sh"

export CREDENTIAL_MANIFEST="$WORK/fixtures/credentials.tsv"
export AWS_BIN="$WORK/stub/aws"
export KUBECTL_BIN="$WORK/stub/kubectl"
export PATH="$WORK/stub:$PATH"
export CALL_LOG="$WORK/calls.log"
export SSM_FIXTURE="$WORK/fixtures/ssm.tsv"
export CLUSTER_FIXTURE="$WORK/fixtures/cluster.tsv"
# 2026-08-26T00:00:00Z. Fixed, so the age arithmetic is the same on every run
# and on every machine.
export NOW_EPOCH=$(date -u -d '2026-08-26T00:00:00Z' +%s)

# ── the stubs ──────────────────────────────────────────────────────────────────
# Every invocation is logged. The log is what the "spends no KMS request" checks
# assert against - not the absence of an error, the absence of the call.
cat > "$WORK/stub/aws" <<'STUB'
#!/usr/bin/env bash
printf 'aws %s\n' "$*" >> "$CALL_LOG"
case " $* " in
  *" describe-parameters "*) cat "$SSM_FIXTURE" ;;
  *" put-parameter "*)       printf '{"Version": 2}\n' ;;
  *) printf 'stub aws: unexpected call: %s\n' "$*" >&2; exit 9 ;;
esac
STUB

cat > "$WORK/stub/kubectl" <<'STUB'
#!/usr/bin/env bash
printf 'kubectl %s\n' "$*" >> "$CALL_LOG"
case " $* " in
  *" get externalsecrets "*) cat "$CLUSTER_FIXTURE" ;;
  *" annotate "*)            printf 'externalsecret.external-secrets.io/x annotated\n' ;;
  *) printf 'stub kubectl: unexpected call: %s\n' "$*" >&2; exit 9 ;;
esac
STUB
chmod +x "$WORK/stub/aws" "$WORK/stub/kubectl"

# ── the fixtures ───────────────────────────────────────────────────────────────
# Object names here are invented. The suite proves the fan-out mechanism, and
# this repository is public, so no real cluster object is named in it.
#
# The PAT row carries fractional seconds and a numeric offset, exactly as AWS
# returns them, because that is the shape most likely to be parsed wrong.
mk_ssm() { # mode: fresh | overdue | missing-pat
  local mode=$1 pat
  case $mode in
    overdue) pat='2026-04-30T14:01:20.597000-05:00' ;;
    *)       pat='2026-08-20T00:00:00Z' ;;
  esac
  {
    [[ $mode == missing-pat ]] || printf '/argocd/github/pat\tSecureString\t%s\n' "$pat"
    printf '/job-hunter/anthropic-api-key\tSecureString\t2026-08-20T00:00:00Z\n'
    printf '/job-hunter/database-url\tSecureString\t2026-08-20T00:00:00Z\n'
    printf '/job-hunter/postgres-password\tSecureString\t2026-08-20T00:00:00Z\n'
    printf '/job-hunter/nats/operator-jwt\tSecureString\t2026-08-20T00:00:00Z\n'
    printf '/job-hunter/nats/account-jwt\tSecureString\t2026-08-20T00:00:00Z\n'
    printf '/job-hunter/nats/account-nkey\tSecureString\t2026-08-20T00:00:00Z\n'
    printf '/job-hunter/nats/sys-account-jwt\tSecureString\t2026-08-20T00:00:00Z\n'
    printf '/job-hunter/nats/sys-account-nkey\tSecureString\t2026-08-20T00:00:00Z\n'
    printf '/job-hunter/nats-creds-jsadmin\tSecureString\t2026-08-20T00:00:00Z\n'
    printf '/job-hunter/nats-creds-scraper\tSecureString\t2026-08-20T00:00:00Z\n'
    printf '/job-hunter/nats-creds-worker\tSecureString\t2026-08-20T00:00:00Z\n'
    printf '/job-hunter/slack-webhook-url\tSecureString\t2026-08-20T00:00:00Z\n'
    printf '/yieldpoint/static-website/pagespeed-api-key\tSecureString\t2026-08-20T00:00:00Z\n'
    printf '/some/parameter/nothing-rotates\tString\t2026-08-20T00:00:00Z\n'
  } > "$SSM_FIXTURE"
}

mk_cluster() { # mode: synced | stale | notready | no-pat-consumers
  local mode=$1 rt=2026-08-25T00:00:00Z ready=True
  case $mode in
    stale)    rt=2026-04-01T00:00:00Z ;;
    notready) ready=False ;;
  esac
  {
    if [[ $mode != no-pat-consumers ]]; then
      # Four namespaces read the one PAT. This is the fan-out `rotate` has to find.
      printf 'argocd\trepo-creds\targocd-ssm-store\t%s\t%s\t/argocd/github/pat\n' "$rt" "$ready"
      printf 'job-hunter\tghcr-pull-secret\taws-ssm\t%s\t%s\t/argocd/github/pat\n' "$rt" "$ready"
      printf 'jenkins\tghcr-pull-secret\tjenkins-ssm-store\t%s\t%s\t/argocd/github/pat\n' "$rt" "$ready"
      printf 'prospector\tghcr-pull-secret\tprospector-ssm-store\t%s\t%s\t/argocd/github/pat\n' "$rt" "$ready"
    fi
    printf 'argocd\trepo-creds\targocd-ssm-store\t%s\t%s\t/argocd/github/username\n' "$rt" "$ready"
    printf 'job-hunter\tclaude-key\taws-ssm\t%s\t%s\t/job-hunter/anthropic-api-key\n' "$rt" "$ready"
    printf 'job-hunter\tdb-creds\taws-ssm\t%s\t%s\t/job-hunter/database-url\n' "$rt" "$ready"
    printf 'job-hunter\tdb-creds\taws-ssm\t%s\t%s\t/job-hunter/postgres-password\n' "$rt" "$ready"
    printf 'job-hunter\tnats-auth\taws-ssm\t%s\t%s\t/job-hunter/nats/operator-jwt\n' "$rt" "$ready"
    printf 'job-hunter\tnats-auth\taws-ssm\t%s\t%s\t/job-hunter/nats/account-jwt\n' "$rt" "$ready"
    printf 'job-hunter\tnats-auth\taws-ssm\t%s\t%s\t/job-hunter/nats/account-nkey\n' "$rt" "$ready"
    printf 'job-hunter\tnats-auth\taws-ssm\t%s\t%s\t/job-hunter/nats/sys-account-jwt\n' "$rt" "$ready"
    printf 'job-hunter\tnats-auth\taws-ssm\t%s\t%s\t/job-hunter/nats/sys-account-nkey\n' "$rt" "$ready"
    printf 'job-hunter\tnats-jsadmin\taws-ssm\t%s\t%s\t/job-hunter/nats-creds-jsadmin\n' "$rt" "$ready"
    printf 'job-hunter\tnats-scraper\taws-ssm\t%s\t%s\t/job-hunter/nats-creds-scraper\n' "$rt" "$ready"
    printf 'job-hunter\tnats-worker\taws-ssm\t%s\t%s\t/job-hunter/nats-creds-worker\n' "$rt" "$ready"
    printf 'job-hunter\tslack-hook\taws-ssm\t%s\t%s\t/job-hunter/slack-webhook-url\n' "$rt" "$ready"
    printf 'yieldpoint-ai\tpagespeed\taws-ssm\t%s\t%s\t/yieldpoint/static-website/pagespeed-api-key\n' "$rt" "$ready"
    # A Vault-backed ExternalSecret. It must never be matched by a parameter path.
    printf 'n8n-dev-workflow\tn8n-jenkins\tn8n-vault-backend\t%s\t%s\tsecret/data/homelab/n8n\n' "$rt" "$ready"
  } > "$CLUSTER_FIXTURE"
}

reset_log() { : > "$CALL_LOG"; }

# ── 1. entry points ────────────────────────────────────────────────────────────
hd "entry points"
expect_rc "--help" 0 bash "$CR" --help
expect_rc "no argument prints usage and exits 0" 0 bash "$CR"
expect_rc "rejects an unknown subcommand" 1 bash "$CR" frobnicate
expect_rc "rejects an unknown flag on due" 1 bash "$CR" due --sideways
expect_rc "rejects an unknown flag on verify" 1 bash "$CR" verify --sideways
expect_rc "rejects an unknown flag on rotate" 1 bash "$CR" rotate --sideways
# --help must answer before the manifest is required. Somebody running --help is
# exactly the person who has not set the tool up yet.
expect_rc "--help works with no manifest at all" 0 \
  env CREDENTIAL_MANIFEST=/nope/nope.tsv bash "$CR" --help

# ── 2. the manifest ────────────────────────────────────────────────────────────
hd "the manifest"
mk_ssm fresh; mk_cluster synced; reset_log
expect_rc "list exits 0" 0 bash "$CR" list
bash "$CR" list > "$WORK/list1.out" 2>&1
check "list reports 14 credentials" \
  "$([[ "$(grep -c '^[a-z]' "$WORK/list1.out")" -eq 14 ]]; echo $?)"
check "list contacts nothing" "$([[ ! -s "$CALL_LOG" ]]; echo $?)"

bash "$CR" list > "$WORK/list2.out" 2>&1
check "list is byte-identical across two runs" \
  "$(cmp -s "$WORK/list1.out" "$WORK/list2.out"; echo $?)"

expect_rc "a missing manifest is refused" 1 \
  env CREDENTIAL_MANIFEST=/nope/nope.tsv bash "$CR" list
printf 'only-two\tfields\n' > "$WORK/fixtures/bad.tsv"
expect_rc "a malformed row is refused, not guessed at" 1 \
  env CREDENTIAL_MANIFEST="$WORK/fixtures/bad.tsv" bash "$CR" list
env CREDENTIAL_MANIFEST="$WORK/fixtures/bad.tsv" bash "$CR" list > "$WORK/bad.out" 2>&1
check "the refusal names the line number" \
  "$(grep -q 'line 1: want 4 tab-separated fields' "$WORK/bad.out"; echo $?)"

# The manifest is a pointer file. This is the check that keeps it one.
hd "the manifest holds no secrets and no PII"
check "no AWS account id" "$(neg grep -qE '[0-9]{12}' "$SRC/credentials.tsv")"
check "no ARN" "$(neg grep -q 'arn:aws' "$SRC/credentials.tsv")"
check "no IP address" "$(neg grep -qE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' "$SRC/credentials.tsv")"
check "no bearer-shaped token" \
  "$(neg grep -qE '(ghp_|github_pat_|sk-|xox[baprs]-|AKIA)' "$SRC/credentials.tsv")"
check "no https URL" "$(neg grep -q 'https://' "$SRC/credentials.tsv")"
# Every non-comment row is exactly a path, an integer and yes/no. Nothing else
# can hide in a file that has to match this.
check "every row is id / path / days / yes-no and nothing more" \
  "$(awk -F'\t' '/^#/ || /^[[:space:]]*$/ {next}
      $2 !~ /^\// || $3 !~ /^[0-9]+$/ || ($4 != "yes" && $4 != "no") {bad=1}
      END {exit bad?1:0}' "$SRC/credentials.tsv"; echo $?)"

# ── 3. due ─────────────────────────────────────────────────────────────────────
hd "due"
mk_ssm fresh; reset_log
expect_rc "due exits 0 when nothing is overdue" 0 bash "$CR" due
check "due asked AWS for metadata only" \
  "$(grep -q 'describe-parameters' "$CALL_LOG"; echo $?)"
check "due never called get-parameter - no KMS request was spent" \
  "$(neg grep -qE 'get-parameter' "$CALL_LOG")"
check "due did not touch the cluster" "$(neg grep -q '^kubectl' "$CALL_LOG")"

mk_ssm overdue; reset_log
expect_rc "due exits 2 when something is overdue" 2 bash "$CR" due
bash "$CR" due > "$WORK/due.out" 2>&1
check "due names the overdue credential" \
  "$(grep -qE '^github-pat .*OVERDUE by [0-9]+d' "$WORK/due.out"; echo $?)"
check "due read the fractional-second, offset timestamp correctly" \
  "$(grep -qE '^github-pat +2026-04-30' "$WORK/due.out"; echo $?)"
check "a credential inside its window is not called overdue" \
  "$(neg grep -qE '^slack-webhook-url .*OVERDUE' "$WORK/due.out")"
check "still no KMS request on the overdue path" \
  "$(neg grep -qE 'get-parameter' "$CALL_LOG")"

mk_ssm fresh; reset_log
expect_rc "--days turns due into a look-ahead and finds the near ones" 2 bash "$CR" due --days 400
expect_rc "--days rejects a non-number" 1 bash "$CR" due --days soon

# A manifest id with no parameter behind it is a defect, not a blank row.
mk_ssm missing-pat; reset_log
expect_rc "due exits 2 when a manifest id has no parameter" 2 bash "$CR" due
bad_out=$(bash "$CR" due 2>&1)
check "due says which id has no parameter" \
  "$(grep -q 'NOT IN PARAMETER STORE' <<< "$bad_out"; echo $?)"

# ── 4. verify ──────────────────────────────────────────────────────────────────
hd "verify"
mk_ssm fresh; mk_cluster synced; reset_log
expect_rc "verify exits 0 when every consumer is in sync" 0 bash "$CR" verify
check "verify never called get-parameter - no KMS request was spent" \
  "$(neg grep -qE 'get-parameter' "$CALL_LOG")"
check "verify made exactly one AWS call" \
  "$([[ "$(grep -c '^aws ' "$CALL_LOG")" -eq 1 ]]; echo $?)"
check "verify made exactly one kubectl call" \
  "$([[ "$(grep -c '^kubectl ' "$CALL_LOG")" -eq 1 ]]; echo $?)"

bash "$CR" verify > "$WORK/verify-ok.out" 2>&1
check "verify found all four consumers of the shared PAT" \
  "$([[ "$(grep -c '^github-pat ' "$WORK/verify-ok.out")" -eq 4 ]]; echo $?)"
check "a Vault-backed ExternalSecret is never matched to a parameter path" \
  "$(neg grep -q 'n8n' "$WORK/verify-ok.out")"

mk_cluster stale; reset_log
expect_rc "verify exits 2 when the cluster is behind the parameter" 2 bash "$CR" verify
bash "$CR" verify > "$WORK/verify-stale.out" 2>&1
check "verify says STALE and by how much" \
  "$(grep -qE 'STALE - parameter changed [0-9]+d after the last refresh' "$WORK/verify-stale.out"; echo $?)"
check "the stale path still spends no KMS request" \
  "$(neg grep -qE 'get-parameter' "$CALL_LOG")"

mk_cluster notready; reset_log
expect_rc "verify exits 2 when an ExternalSecret is not Ready" 2 bash "$CR" verify
bash "$CR" verify > "$WORK/verify-nr.out" 2>&1
check "a not-Ready ExternalSecret is reported as such, not as in sync" \
  "$(grep -q 'NOT READY' "$WORK/verify-nr.out"; echo $?)"

mk_cluster no-pat-consumers; reset_log
expect_rc "verify exits 2 when a credential has no consumer at all" 2 bash "$CR" verify
bash "$CR" verify > "$WORK/verify-orphan.out" 2>&1
check "an orphaned credential is named rather than skipped" \
  "$(grep -q 'no ExternalSecret reads this parameter' "$WORK/verify-orphan.out"; echo $?)"

mk_cluster synced
expect_rc "verify --id narrows to one credential" 0 bash "$CR" verify --id github-pat
bash "$CR" verify --id github-pat > "$WORK/verify-one.out" 2>&1
check "verify --id printed only that credential" \
  "$([[ "$(grep -c '^github-pat ' "$WORK/verify-one.out")" -eq 4 ]] \
    && [[ "$(grep -c '^slack-webhook-url ' "$WORK/verify-one.out")" -eq 0 ]]; echo $?)"
expect_rc "verify --id rejects an unknown id" 1 bash "$CR" verify --id nope

# ── 5. rotate ──────────────────────────────────────────────────────────────────
hd "rotate: the refusals"
mk_ssm fresh; mk_cluster synced
printf 'a-new-token-value' > "$WORK/new.txt"
: > "$WORK/empty.txt"

expect_rc "rotate needs --id" 1 bash "$CR" rotate --value-file "$WORK/new.txt"
expect_rc "rotate needs --value-file" 1 bash "$CR" rotate --id github-pat
expect_rc "rotate rejects an unknown id" 1 \
  bash "$CR" rotate --id nope --value-file "$WORK/new.txt"
expect_rc "rotate rejects a value file that does not exist" 1 \
  bash "$CR" rotate --id github-pat --value-file "$WORK/nope.txt"
# The single most likely way this command destroys a live credential: the mint
# step failed, the redirect made the file anyway, and put-parameter writes "".
expect_rc "rotate REFUSES an empty value file" 1 \
  bash "$CR" rotate --id github-pat --value-file "$WORK/empty.txt"
reset_log
bash "$CR" rotate --id github-pat --value-file "$WORK/empty.txt" >/dev/null 2>&1
check "the empty-file refusal wrote nothing at all" \
  "$(neg grep -qE 'put-parameter|annotate' "$CALL_LOG")"

mk_cluster no-pat-consumers
expect_rc "rotate refuses when nothing in the cluster reads the parameter" 1 \
  bash "$CR" rotate --id github-pat --value-file "$WORK/new.txt"

hd "rotate --dry-run"
mk_cluster synced; reset_log
expect_rc "dry run exits 0" 0 \
  bash "$CR" rotate --id github-pat --value-file "$WORK/new.txt" --dry-run
bash "$CR" rotate --id github-pat --value-file "$WORK/new.txt" --dry-run \
  > "$WORK/dry.out" 2>&1
check "dry run listed all four consumers of the shared PAT" \
  "$([[ "$(grep -cE '^ +- (argocd|job-hunter|jenkins|prospector)/' "$WORK/dry.out")" -eq 4 ]]; echo $?)"
check "dry run named every one of the four namespaces" \
  "$(for ns in argocd job-hunter jenkins prospector; do
       grep -q "  - $ns/" "$WORK/dry.out" || exit 1; done; echo $?)"
check "dry run said it wrote nothing" \
  "$(grep -q 'dry run - nothing was written' "$WORK/dry.out"; echo $?)"
check "dry run really wrote nothing" \
  "$(neg grep -qE 'put-parameter|annotate' "$CALL_LOG")"
check "dry run did not print the new value" \
  "$(neg grep -q 'a-new-token-value' "$WORK/dry.out")"

hd "rotate: coexist is surfaced before anything is written"
bash "$CR" rotate --id job-hunter-postgres-password --value-file "$WORK/new.txt" \
  --dry-run > "$WORK/dry-nocoexist.out" 2>&1
check "coexist=no carries the warning that the old value dies immediately" \
  "$(grep -q 'the old value dies the moment the new one' "$WORK/dry-nocoexist.out"; echo $?)"
check "coexist=yes does not carry that warning" \
  "$(neg grep -q 'the old value dies the moment' "$WORK/dry.out")"

hd "rotate: the real path"
reset_log
# The scratch file is written into TMPDIR. Pointing TMPDIR somewhere countable is
# how the "it cleaned up after itself" check below can be an assertion rather
# than a hope - and the plaintext credential is exactly the file you do not want
# left behind on disk.
export TMPDIR="$WORK/tmpdir"
mkdir -p "$TMPDIR"
expect_rc "rotate exits 0" 0 \
  bash "$CR" rotate --id github-pat --value-file "$WORK/new.txt"
check "the scratch file holding the plaintext value was removed" \
  "$([[ "$(find "$TMPDIR" -type f | wc -l)" -eq 0 ]]; echo $?)"
check "rotate wrote the parameter once" \
  "$([[ "$(grep -c 'put-parameter' "$CALL_LOG")" -eq 1 ]]; echo $?)"
check "rotate forced all four consumers" \
  "$([[ "$(grep -c 'annotate externalsecret' "$CALL_LOG")" -eq 4 ]]; echo $?)"
check "rotate wrote it as a SecureString, overwriting" \
  "$(grep -q 'put-parameter.*--type SecureString --overwrite' "$CALL_LOG"; echo $?)"
# argv is visible in ps and lands in shell history. The value goes via file://.
check "the value never appeared on a command line" \
  "$(neg grep -q 'a-new-token-value' "$CALL_LOG")"
check "the value was handed over as a file reference" \
  "$(grep -q 'put-parameter.*--value file://' "$CALL_LOG"; echo $?)"

# A trailing newline on a token is invisible in every log and breaks auth
# everywhere the value is used, so it is stripped before the write.
printf 'token-with-newline\n' > "$WORK/nl.txt"
reset_log
CAPTURE="$WORK/captured-value"
cat > "$WORK/stub/aws" <<'STUB'
#!/usr/bin/env bash
printf 'aws %s\n' "$*" >> "$CALL_LOG"
case " $* " in
  *" describe-parameters "*) cat "$SSM_FIXTURE" ;;
  *" put-parameter "*)
    for a in "$@"; do
      case $a in file://*) cp "${a#file://}" "$CAPTURE" ;; esac
    done
    printf '{"Version": 2}\n' ;;
  *) printf 'stub aws: unexpected call: %s\n' "$*" >&2; exit 9 ;;
esac
STUB
chmod +x "$WORK/stub/aws"
export CAPTURE
bash "$CR" rotate --id github-pat --value-file "$WORK/nl.txt" >/dev/null 2>&1
check "the trailing newline was stripped before the write" \
  "$([[ "$(wc -c < "$CAPTURE" | tr -d ' ')" -eq 18 ]]; echo $?)"
check "the value itself survived intact" \
  "$([[ "$(cat "$CAPTURE")" == 'token-with-newline' ]]; echo $?)"

# ── 6. the driver did not write next to itself ─────────────────────────────────
hd "the source is untouched"
check "credential-rotation.sh is byte-identical to the one in the repo" \
  "$(cmp -s "$CR" "$SRC/credential-rotation.sh"; echo $?)"
check "credentials.tsv is byte-identical to the one in the repo" \
  "$(cmp -s "$WORK/fixtures/credentials.tsv" "$SRC/credentials.tsv"; echo $?)"

# ── summary ────────────────────────────────────────────────────────────────────
printf '\n=========================================\n'
printf '  PASS %d   FAIL %d\n' "$PASS" "$FAIL"
printf '=========================================\n'
[[ $FAIL -eq 0 ]]
