#!/usr/bin/env bash
#
# live-check.sh - runs the driver's read-only subcommands against the real AWS
# account and the real cluster, from inside a container.
#
# WHY THIS EXISTS SEPARATELY FROM run-tests.sh
#
# run-tests.sh stubs `aws` and `kubectl` and runs with --network=none. That is
# what lets it assert the property this workflow is built around: no code path
# ever spends a KMS request. The cost is that the go-template which turns real
# ExternalSecrets into rows is never rendered by a real kubectl, and a stub
# cannot prove a template renders. This closes that one gap.
#
# WHAT IT IS ALLOWED TO DO
#
#   list    reads a file
#   due     one ssm describe-parameters - metadata, no decrypt
#   verify  the above plus one kubectl get - no decrypt
#
# `rotate` is not run here and there is no flag that would run it. A check that
# writes to production is not a check.
#
# THE THREE FLAGS THAT MAKE IT SAFE
#
#   --network=none is deliberately ABSENT, because reaching AWS and the cluster
#   is the entire point. Everything else stays locked down:
#
#   -v repo:ro          the driver cannot write next to itself
#   -v ~/.aws:ro        credentials are readable, never writable
#   -v ~/.kube:ro       same for the kubeconfig
#   --userns=keep-id    the mounted credentials are readable as you, not root
#
# USAGE
#   bash live-check.sh                     uses AWS_PROFILE from the environment
#   AWS_PROFILE=other bash live-check.sh
set -uo pipefail

HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$HERE/../../.." && pwd)
IMAGE="${CREDROT_LIVE_IMAGE:-localhost/credrot-live:1}"
PROFILE="${AWS_PROFILE:-minecraft-admin}"
CONTEXT="${KUBE_CONTEXT:-homelab-admin}"

if [[ ${IN_CREDROT_LIVE:-0} != 1 ]]; then
  command -v podman >/dev/null 2>&1 || {
    printf 'podman is required: this check runs in a container.\n' >&2; exit 1; }
  [[ -d "$HOME/.aws" ]]  || { printf 'no ~/.aws to mount\n' >&2; exit 1; }
  [[ -d "$HOME/.kube" ]] || { printf 'no ~/.kube to mount\n' >&2; exit 1; }
  if ! podman image exists "$IMAGE"; then
    printf 'building %s\n' "$IMAGE"
    podman build -t "$IMAGE" -f "$HERE/Containerfile.live" "$HERE" >/dev/null || {
      printf 'image build failed\n' >&2; exit 1; }
  fi
  exec podman run --rm --userns=keep-id \
    -v "$REPO_ROOT:/repo:ro,Z" \
    -v "$HOME/.aws:/creds/aws:ro,Z" \
    -v "$HOME/.kube:/creds/kube:ro,Z" \
    -w /tmp \
    -e IN_CREDROT_LIVE=1 -e AWS_PROFILE="$PROFILE" -e KUBE_CONTEXT="$CONTEXT" \
    -e AWS_CONFIG_FILE=/creds/aws/config \
    -e AWS_SHARED_CREDENTIALS_FILE=/creds/aws/credentials \
    -e KUBECONFIG=/creds/kube/config \
    --entrypoint="" "$IMAGE" \
    bash /repo/workflows/credential-rotation/testing/live-check.sh
fi

# ── inside the container from here ─────────────────────────────────────────────
CR=/repo/workflows/credential-rotation/credential-rotation.sh
PASS=0
FAIL=0
ok()  { printf '  PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
bad() { printf '  FAIL  %s\n' "$1"; FAIL=$((FAIL + 1)); }
hd()  { printf '\n=== %s\n' "$1"; }
check() { if [[ $2 -eq 0 ]]; then ok "$1"; else bad "$1"; fi; }

hd "the environment this is running in"
printf '  aws      %s\n' "$(aws --version 2>&1)"
printf '  kubectl  %s\n' "$(kubectl version --client -o json 2>/dev/null \
  | tr -d ' \n' | sed -E 's/.*"gitVersion":"([^"]+)".*/\1/')"
printf '  profile  %s\n' "$AWS_PROFILE"
printf '  context  %s\n' "$KUBE_CONTEXT"

hd "reachability"
aws sts get-caller-identity >/dev/null 2>&1
check "the AWS profile authenticates" $?
kubectl --context "$KUBE_CONTEXT" get --raw /readyz >/dev/null 2>&1
check "the cluster answers" $?

hd "list"
bash "$CR" list > /tmp/list.out 2>&1
check "list exits 0" $?
check "list reports 14 credentials" \
  "$([[ "$(grep -c '^[a-z]' /tmp/list.out)" -eq 14 ]]; echo $?)"

hd "due against the real Parameter Store"
bash "$CR" due > /tmp/due.out 2>&1
rc=$?
printf '%s\n' "$(sed 's/^/  | /' /tmp/due.out)"
# 0 is nothing overdue, 2 is something overdue. Both mean it ran and read the
# real timestamps. Anything else is the driver failing.
check "due ran and returned a reporting exit code (got $rc)" \
  "$([[ $rc -eq 0 || $rc -eq 2 ]]; echo $?)"
check "every manifest id was found in Parameter Store" \
  "$(if grep -q 'NOT IN PARAMETER STORE' /tmp/due.out; then echo 1; else echo 0; fi)"

hd "verify: the go-template against real ExternalSecrets"
bash "$CR" verify > /tmp/verify.out 2>&1
rc=$?
printf '%s\n' "$(sed 's/^/  | /' /tmp/verify.out)"
check "verify ran and returned a reporting exit code (got $rc)" \
  "$([[ $rc -eq 0 || $rc -eq 2 ]]; echo $?)"
# This is the assertion the stubbed suite cannot make. If the template failed to
# render, every credential would come back with no consumer.
check "the template rendered - at least one real consumer was matched" \
  "$(if grep -q 'no ExternalSecret reads this parameter' /tmp/verify.out \
      && [[ "$(grep -cv 'no ExternalSecret\|^ID ' /tmp/verify.out)" -eq 0 ]]; \
     then echo 1; else echo 0; fi)"
check "the shared PAT resolved to its four namespaces" \
  "$([[ "$(grep -c '^github-pat ' /tmp/verify.out)" -eq 4 ]]; echo $?)"
check "no Vault-backed ExternalSecret was matched to a parameter path" \
  "$(if grep -qE 'vault-backend|vault_backend' /tmp/verify.out; then echo 1; else echo 0; fi)"

printf '\n=========================================\n'
printf '  PASS %d   FAIL %d\n' "$PASS" "$FAIL"
printf '=========================================\n'
[[ $FAIL -eq 0 ]]
