#!/usr/bin/env bash
#
# credential-rotation.sh - the driver for workflows/credential-rotation.md.
#
# The procedure document carries the version for both of them. One number,
# because the script and the document have to move together and two numbers
# that must agree is just a drift bug waiting for somebody to notice it.
#
# WHAT THIS DOES AND DOES NOT DO
#
# It does not mint credentials. A new GitHub token, a new Slack webhook, a new
# Google API key - those are created by a human at the provider, and there is no
# flag here that pretends otherwise. What it owns is the mechanical half that a
# human gets wrong: writing the new value to Parameter Store, reaching every
# ExternalSecret that consumes it, and proving the cluster is actually serving
# the new value afterwards.
#
# THE KMS PROPERTY THAT SHAPES ALL OF THIS
#
# Reading a SecureString parameter costs a billable kms:Decrypt every time, even
# when the value has not changed. That is the entire reason refreshInterval moved
# to 168h. A verifier that read each parameter to compare it against the cluster
# would spend one Decrypt per credential per run and quietly undo the thing this
# workflow exists to protect.
#
# So `due` and `verify` never read a value. They compare two timestamps:
#
#   the parameter's LastModifiedDate   from ssm describe-parameters   free
#   the ExternalSecret's refreshTime   from kubectl                   free
#
# If the cluster last refreshed before the parameter last changed, the cluster is
# serving a stale value. That is a complete answer, it works for templated
# secrets where no plain key holds the raw value, and it costs nothing.
#
# The whole run is two API calls: one to AWS, one to the cluster. Zero KMS.
#
# ENVIRONMENT
#   CREDENTIAL_MANIFEST  path to credentials.tsv (default: next to this script)
#   AWS_BIN              aws binary            (default: aws)
#   KUBECTL_BIN          kubectl binary        (default: kubectl)
#   KUBE_CONTEXT         cluster context       (default: homelab-admin)
#   SSM_REGION           parameter region      (default: us-east-2)
#   NOW_EPOCH            override "now" in seconds, for the tests
set -euo pipefail

SELF=$(basename "$0")
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

MANIFEST=${CREDENTIAL_MANIFEST:-$HERE/credentials.tsv}
AWS_BIN=${AWS_BIN:-aws}
KUBECTL_BIN=${KUBECTL_BIN:-kubectl}
KUBE_CONTEXT=${KUBE_CONTEXT:-homelab-admin}
SSM_REGION=${SSM_REGION:-us-east-2}

die() { printf '%s: %s\n' "$SELF" "$*" >&2; exit 1; }

# The scratch file `rotate` writes the new value into. It is global and the trap
# is installed at file scope on purpose: a trap body is evaluated when the trap
# fires, not when it is installed, so a `local` set inside a function is already
# out of scope by the time EXIT runs - and under `set -u` that turns a clean exit
# into an unbound-variable failure with the work already done.
TMP_VALUE=''
cleanup() { if [[ -n $TMP_VALUE ]]; then rm -f -- "$TMP_VALUE"; fi; return 0; }
trap cleanup EXIT INT TERM

usage() {
  cat <<EOF
USAGE
  $SELF list
  $SELF due [--days N]
  $SELF verify [--id ID]
  $SELF rotate --id ID --value-file FILE [--dry-run]
  $SELF --help

SUBCOMMANDS
  list     Print the manifest. Reads no parameter, contacts nothing.

  due      Which credentials are past their rotate_days. One ssm
           describe-parameters call, which returns metadata only and spends no
           KMS request. --days N narrows it to what falls due within N days,
           so it is also the "what is coming up" view.

  verify   Which ExternalSecrets are serving a value older than the parameter
           behind them. One AWS call, one kubectl call, no KMS request. --id
           narrows it to one credential.

  rotate   Write a new value to Parameter Store and force every consuming
           ExternalSecret to re-read it. The value comes from a file, never
           from the command line, because an argument is visible in ps and
           lands in shell history. --dry-run prints the plan and writes
           nothing, and is the correct first run every single time.

EXIT CODES
  0  ok, and for due/verify: nothing overdue, nothing stale
  1  usage, or a missing dependency
  2  due found something overdue, or verify found something stale
  3  the operation was attempted and failed

FILES
  $MANIFEST
EOF
}

# ── the manifest ───────────────────────────────────────────────────────────────
# Comments and blank lines out, everything else through untouched. Nothing here
# validates the shape beyond the field count: a manifest is a short hand-written
# file and a parser that guesses at a malformed row is worse than one that stops.
manifest_rows() {
  [[ -f $MANIFEST ]] || die "manifest not found: $MANIFEST"
  local line n=0 fields
  while IFS= read -r line || [[ -n $line ]]; do
    n=$((n + 1))
    if [[ -z ${line//[[:space:]]/} ]]; then continue; fi
    if [[ $line == \#* ]]; then continue; fi
    fields=$(printf '%s' "$line" | awk -F'\t' '{print NF}')
    if [[ $fields -ne 4 ]]; then
      die "$MANIFEST line $n: want 4 tab-separated fields, got $fields"
    fi
    printf '%s\n' "$line"
  done < "$MANIFEST"
}

# Read once, into a variable, rather than feeding manifest_rows to each loop
# through a process substitution. `done < <(manifest_rows)` runs the parser in a
# subshell, so a die() in there kills only the subshell and the loop simply sees
# end-of-input: the refusal is printed and the exit code is still 0. A refusal
# that does not fail is not a refusal, and it is exactly the hole that would let
# a malformed manifest through.
MANIFEST_ROWS=''
load_manifest() {
  if [[ -n $MANIFEST_ROWS ]]; then return 0; fi
  # A failed command substitution fails this assignment, and set -e takes it
  # from there. That is the whole reason this is an assignment and not a pipe.
  MANIFEST_ROWS=$(manifest_rows)
  [[ -n $MANIFEST_ROWS ]] || die "$MANIFEST has no credential rows"
}

row_for() {
  local want=$1 row
  load_manifest
  while IFS= read -r row; do
    if [[ $(printf '%s' "$row" | cut -f1) == "$want" ]]; then
      printf '%s\n' "$row"; return 0
    fi
  done <<< "$MANIFEST_ROWS"
  return 1
}

known_ids() { load_manifest; printf '%s\n' "$MANIFEST_ROWS" | cut -f1 | tr '\n' ' '; }

# ── timestamps ─────────────────────────────────────────────────────────────────
# AWS hands back fractional seconds and a numeric offset
# (2026-04-30T14:01:20.597000-05:00); the cluster hands back plain UTC
# (2026-08-26T15:41:50Z). Dropping the fraction makes one shape out of both, and
# nothing here cares about sub-second resolution on a value that lives 90 days.
to_epoch() {
  local s=${1:-}
  if [[ -z $s || $s == '-' || $s == '<none>' ]]; then printf '0\n'; return 0; fi
  s=$(printf '%s' "$s" | sed -E 's/\.[0-9]+//')
  date -u -d "$s" +%s 2>/dev/null || printf '0\n'
}

now_epoch() { printf '%s\n' "${NOW_EPOCH:-$(date -u +%s)}"; }

days_between() { printf '%s\n' $(((${1:-0} - ${2:-0}) / 86400)); }

# ── the two snapshots ──────────────────────────────────────────────────────────
# describe-parameters returns metadata only. It is not GetParameter and it does
# not decrypt, which is the property the whole design rests on.
ssm_snapshot() {
  command -v "$AWS_BIN" >/dev/null 2>&1 || die "aws not found: $AWS_BIN"
  "$AWS_BIN" ssm describe-parameters --region "$SSM_REGION" \
    --query 'Parameters[].[Name,Type,LastModifiedDate]' --output text \
    || die "aws ssm describe-parameters failed"
}

# One row per (ExternalSecret, remoteRef) pair, so a single ExternalSecret that
# reads five parameters appears five times and each one can be matched
# independently. go-template rather than jsonpath because jsonpath cannot carry
# the parent's namespace and name down into a nested range, and go-template
# rather than jq so the test image stays bash and coreutils.
CLUSTER_TEMPLATE='{{range .items}}{{$ns := .metadata.namespace}}{{$n := .metadata.name}}{{$store := "-"}}{{with .spec.secretStoreRef}}{{$store = .name}}{{end}}{{$rt := "-"}}{{$ready := "-"}}{{with .status}}{{with .refreshTime}}{{$rt = .}}{{end}}{{range .conditions}}{{if eq .type "Ready"}}{{$ready = .status}}{{end}}{{end}}{{end}}{{range .spec.data}}{{$ns}}{{"\t"}}{{$n}}{{"\t"}}{{$store}}{{"\t"}}{{$rt}}{{"\t"}}{{$ready}}{{"\t"}}{{.remoteRef.key}}{{"\n"}}{{end}}{{end}}'

cluster_snapshot() {
  command -v "$KUBECTL_BIN" >/dev/null 2>&1 || die "kubectl not found: $KUBECTL_BIN"
  "$KUBECTL_BIN" --context "$KUBE_CONTEXT" get externalsecrets -A \
    -o go-template="$CLUSTER_TEMPLATE" \
    || die "kubectl get externalsecrets failed"
}

# Every ExternalSecret whose remoteRef points at this parameter. Discovered, not
# declared - see the note at the top of credentials.tsv for why.
consumers_of() {
  local param=$1 snap=$2
  awk -F'\t' -v p="$param" '$6 == p { print $1 "\t" $2 "\t" $3 "\t" $4 "\t" $5 }' <<< "$snap"
}

# ── list ───────────────────────────────────────────────────────────────────────
cmd_list() {
  load_manifest
  printf '%-30s %-46s %6s  %s\n' ID PARAMETER DAYS COEXIST
  local id param days co
  while IFS=$'\t' read -r id param days co; do
    printf '%-30s %-46s %6s  %s\n' "$id" "$param" "$days" "$co"
  done <<< "$MANIFEST_ROWS"
}

# ── due ────────────────────────────────────────────────────────────────────────
cmd_due() {
  local within='' arg
  while [[ $# -gt 0 ]]; do
    arg=$1
    case $arg in
      --days) within=${2:-}; shift 2 ;;
      *) die "unknown flag for due: $arg" ;;
    esac
  done
  [[ -z $within || $within =~ ^[0-9]+$ ]] || die "--days wants a whole number (got: $within)"

  load_manifest
  local snap now overdue=0 unknown=0
  snap=$(ssm_snapshot)
  now=$(now_epoch)

  printf '%-30s %12s %8s  %s\n' ID 'LAST CHANGED' 'AGE/DAY' STATE
  local id param days co mod age left state
  while IFS=$'\t' read -r id param days co; do
    mod=$(awk -F'\t' -v p="$param" '$1 == p { print $3 }' <<< "$snap" | head -1)
    if [[ -z $mod ]]; then
      printf '%-30s %12s %8s  %s\n' "$id" '-' '-' 'NOT IN PARAMETER STORE'
      unknown=1
      continue
    fi
    age=$(days_between "$now" "$(to_epoch "$mod")")
    left=$((days - age))
    if [[ $left -le 0 ]]; then
      state="OVERDUE by $((-left))d"
      overdue=1
    elif [[ -n $within && $left -le $within ]]; then
      state="due in ${left}d"
      overdue=1
    else
      state="ok, ${left}d left"
    fi
    printf '%-30s %12s %8s  %s\n' "$id" "${mod%%T*}" "$age/$days" "$state"
  done <<< "$MANIFEST_ROWS"

  # An id in the manifest with no parameter behind it is a real defect - either
  # somebody deleted the parameter or the path is wrong - and it is reported as a
  # failure rather than a blank row, because a blank row reads as "fine".
  [[ $unknown -eq 1 ]] && return 2
  [[ $overdue -eq 1 ]] && return 2
  return 0
}

# ── verify ─────────────────────────────────────────────────────────────────────
cmd_verify() {
  local only='' arg
  while [[ $# -gt 0 ]]; do
    arg=$1
    case $arg in
      --id) only=${2:-}; shift 2 ;;
      *) die "unknown flag for verify: $arg" ;;
    esac
  done
  if [[ -n $only ]]; then
    row_for "$only" >/dev/null || die "unknown id: $only (known: $(known_ids))"
  fi

  load_manifest
  local ssm cluster stale=0 orphan=0
  ssm=$(ssm_snapshot)
  cluster=$(cluster_snapshot)

  printf '%-30s %-34s %-10s %s\n' ID CONSUMER READY STATE
  local id param days co mod modep any ns name store rt ready rtep
  while IFS=$'\t' read -r id param days co; do
    [[ -n $only && $id != "$only" ]] && continue
    mod=$(awk -F'\t' -v p="$param" '$1 == p { print $3 }' <<< "$ssm" | head -1)
    modep=$(to_epoch "$mod")
    any=0
    while IFS=$'\t' read -r ns name store rt ready; do
      [[ -z $ns ]] && continue
      any=1
      rtep=$(to_epoch "$rt")
      local state
      if [[ $ready != True ]]; then
        state="NOT READY - ESO is not syncing this one"
        stale=1
      elif [[ $modep -eq 0 ]]; then
        state='parameter not found in SSM'
        stale=1
      elif [[ $rtep -lt $modep ]]; then
        state="STALE - parameter changed $(days_between "$modep" "$rtep")d after the last refresh"
        stale=1
      else
        state='in sync'
      fi
      printf '%-30s %-34s %-10s %s\n' "$id" "$ns/$name" "$ready" "$state"
    done < <(consumers_of "$param" "$cluster")
    if [[ $any -eq 0 ]]; then
      printf '%-30s %-34s %-10s %s\n' "$id" '(none)' '-' 'no ExternalSecret reads this parameter'
      orphan=1
    fi
  done <<< "$MANIFEST_ROWS"

  # An orphan is not stale, but it is worth a non-zero exit: a credential nobody
  # consumes is either a parameter that should be deleted or a consumer that
  # should exist and does not, and both want a human.
  [[ $stale -eq 1 || $orphan -eq 1 ]] && return 2
  return 0
}

# ── rotate ─────────────────────────────────────────────────────────────────────
cmd_rotate() {
  local id='' value_file='' dry=0 arg
  while [[ $# -gt 0 ]]; do
    arg=$1
    case $arg in
      --id) id=${2:-}; shift 2 ;;
      --value-file) value_file=${2:-}; shift 2 ;;
      --dry-run) dry=1; shift ;;
      *) die "unknown flag for rotate: $arg" ;;
    esac
  done
  [[ -n $id ]] || die "rotate needs --id (known: $(known_ids))"
  [[ -n $value_file ]] || die "rotate needs --value-file"

  local row; row=$(row_for "$id") || die "unknown id: $id (known: $(known_ids))"
  local param days co
  param=$(cut -f2 <<< "$row"); days=$(cut -f3 <<< "$row"); co=$(cut -f4 <<< "$row")

  [[ -f $value_file ]] || die "no such value file: $value_file"
  # A zero-length file is the most likely way this command destroys something:
  # the mint step failed, the redirect still created the file, and put-parameter
  # would happily write the empty string over a live credential.
  [[ -s $value_file ]] || die "value file is empty: $value_file - refusing to write an empty credential"

  local cluster
  cluster=$(cluster_snapshot)
  local fanout; fanout=$(consumers_of "$param" "$cluster")

  printf 'credential   %s\n' "$id"
  printf 'parameter    %s  (SecureString, %s)\n' "$param" "$SSM_REGION"
  printf 'policy       rotate every %sd, coexist=%s\n' "$days" "$co"
  if [[ $co == no ]]; then
    printf '             coexist=no - the old value dies the moment the new one\n'
    printf '             exists, so every consumer below is broken until it syncs\n'
  fi
  printf 'new value    %s (%s bytes)\n' "$value_file" "$(wc -c < "$value_file" | tr -d ' ')"
  printf 'consumers    %s ExternalSecret(s) discovered in the cluster\n' \
    "$(printf '%s' "$fanout" | grep -c . || true)"
  local ns name store rt ready
  while IFS=$'\t' read -r ns name store rt ready; do
    [[ -z $ns ]] && continue
    printf '             - %s/%s  store=%s ready=%s\n' "$ns" "$name" "$store" "$ready"
  done <<< "$fanout"

  if [[ -z ${fanout//[[:space:]]/} ]]; then
    die "no ExternalSecret in the cluster reads $param - rotating it would change nothing"
  fi

  if [[ $dry -eq 1 ]]; then
    printf '\ndry run - nothing was written\n'
    return 0
  fi

  # The value goes to AWS through a file, never through argv, and the trailing
  # newline an editor or a redirect leaves behind is stripped first. A newline on
  # the end of a token is invisible in every log and breaks authentication
  # everywhere the value is used.
  TMP_VALUE=$(mktemp)
  chmod 600 "$TMP_VALUE"
  printf '%s' "$(< "$value_file")" > "$TMP_VALUE"

  printf '\nwriting %s\n' "$param"
  "$AWS_BIN" ssm put-parameter --region "$SSM_REGION" --name "$param" \
    --type SecureString --overwrite --value "file://$TMP_VALUE" >/dev/null \
    || die "put-parameter failed - nothing was forced to re-read, the cluster still has the old value"

  # ESO re-reads on any change to the object. An annotation carrying the current
  # epoch is the documented way to make that change without touching the spec,
  # and it is the same annotation runbooks/kms-cost-and-eso-refresh uses.
  local stamp; stamp=$(now_epoch)
  while IFS=$'\t' read -r ns name store rt ready; do
    [[ -z $ns ]] && continue
    printf 'forcing %s/%s\n' "$ns" "$name"
    "$KUBECTL_BIN" --context "$KUBE_CONTEXT" annotate externalsecret "$name" \
      -n "$ns" "force-sync=$stamp" --overwrite >/dev/null \
      || die "could not annotate $ns/$name - the parameter IS rotated, so finish the rest by hand"
  done <<< "$fanout"

  printf '\nwritten and forced. Confirm with:\n  %s verify --id %s\n' "$SELF" "$id"
  printf 'Then restart anything holding the old value as an environment variable -\n'
  printf 'a running pod does not pick up a changed Secret on its own.\n'
}

# ── entry point ────────────────────────────────────────────────────────────────
# --help is answered before the manifest is required, so the one command whose
# job is to explain the tool cannot refuse to run because the tool is not set up.
case ${1:---help} in
  -h|--help|help) usage; exit 0 ;;
esac

cmd=$1; shift
case $cmd in
  list)   cmd_list "$@" ;;
  due)    cmd_due "$@" ;;
  verify) cmd_verify "$@" ;;
  rotate) cmd_rotate "$@" ;;
  *)      usage >&2; die "unknown subcommand: $cmd" ;;
esac
