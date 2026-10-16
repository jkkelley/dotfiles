#!/usr/bin/env bash
# shellcheck disable=SC2016 # jq programs and the NATS $JS subject are single-quoted on purpose
# lib.sh - config, bus, phone and dedupe helpers shared by stuck-watch.sh, deadman.sh and stuck-audit.sh. No model calls.
# name: lib.sh
# purpose: config, bus, ntfy, dedupe and evidence helpers for stuck-watch, deadman and stuck-audit
# inputs: stuck-watch/config.json, SW_* env, ENV_FILE, NTFY_TOPIC_VAR
# outputs: none (sourced)
# writes-to: NATS, ntfy, artifact store trace/, ~/.local/state/zenith/stuck-watch
# cleanup: make stuck-watch-clean
# Sets no shell options (see bin/workflow-lib.sh BREADCRUMB): each caller declares its own.
#
# BREADCRUMB - the ntfy topic is parsed out of the env file, never sourced and never printed.
# What broke: nothing yet; the rejected alternative. Sourcing ~/.config/zenith/yieldpoint.env would export every secret in it
#   into a long-running loop and run any stray line as code; echoing the URL in a log puts the topic (a bearer secret: anyone
#   holding it can page the owner) into the artifact store.
# Why this fix: one key is read by a parser (the business repo's scripts/env.sh rule, WO-20261016-fdda), the file must be
#   mode 0600, and logs carry only the HTTP code. Rejected: depending on that repo's loader, which is not on this tree.
# Cost: a value containing ' #' is cut there (inline comment rule); the topic is a plain token.
SW_DIR="${SW_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
SW_CONFIG="${SW_CONFIG:-$SW_DIR/config.json}"

sw_die() { printf 'stuck-watch: %s\n' "$*" >&2; exit 1; }
sw_cfg() { jq -r "$1" "$SW_CONFIG"; }
# sw_val <env-name> <jq-key>: the env override if set, else the config value.
sw_val() { local e="${!1:-}"; if [ -n "$e" ]; then printf '%s' "$e"; else sw_cfg ".$2"; fi; }
sw_expand() { case "$1" in [~]/*) printf '%s/%s' "$HOME" "${1#[~]/}" ;; *) printf '%s' "$1" ;; esac; }
sw_now() { date -u +%Y-%m-%dT%H:%M:%SZ; }
sw_tok() { printf '%s' "${1:-none}" | tr -c 'A-Za-z0-9_\n-' '-'; }

sw_state_dir() { local d; d="$(sw_expand "$(sw_val SW_STATE_DIR state_dir)")"; mkdir -p "$d"; printf '%s' "$d"; }

# sw_pub <subject> <payload>: NATS core PUB over /dev/tcp (no client binary; seat-resources.sh does the same). The LINE
# stream captures line.> so a core publish is stored. SW_PUB_CMD replaces the transport (tests). Returns 1 when the bus
# is unreachable, so the caller can say so; never exits.
sw_pub() {
  local s="$1" m="$2" url host port ok=""
  if [ -n "${SW_PUB_CMD:-}" ]; then $SW_PUB_CMD "$s" "$m"; return; fi
  url="$(sw_val SW_NATS_URL nats_url)"; host="${url%%:*}"; port="${url##*:}"
  { exec 9<>"/dev/tcp/$host/$port"; } 2>/dev/null || return 1
  printf 'CONNECT {"verbose":false}\r\nPUB %s %d\r\n%s\r\nPING\r\n' "$s" "$(printf '%s' "$m" | wc -c)" "$m" >&9
  while read -r -t 2 ok <&9 2>/dev/null; do case "$ok" in PONG*) break ;; esac; done; exec 9>&-
  case "$ok" in PONG*) return 0 ;; *) return 1 ;; esac
}

# sw_topic: the ntfy topic from the env file. NTFY_TOPIC_VAR names the key (item 35: every test and gate passes
# NTFY_TOPIC_VAR=YPC_NTFY_TEST_TOPIC; only stable real events read the config default YPC_NTFY_TOPIC). Empty when unset.
sw_topic() {
  local f key mode line v
  f="$(sw_expand "${ENV_FILE:-$(sw_val SW_ENV_FILE env_file)}")"; key="${NTFY_TOPIC_VAR:-$(sw_cfg .topic_key)}"
  [ -r "$f" ] || { echo "stuck-watch: env file unreadable, phone disabled" >&2; return 1; }
  mode="$(stat -c '%a' "$f")"; (( (8#$mode & 8#077) == 0 )) || { echo "stuck-watch: env file must be 0600, phone disabled" >&2; return 1; }
  line="$(grep -E "^[[:space:]]*(export[[:space:]]+)?$key=" "$f" | tail -1)"; v="${line#*=}"
  # an inline comment ("value  # note") is not part of the value: the env file carries one on each ntfy line, and a
  # '#' left in the URL made curl drop the rest as a fragment, so GET /<topic>/json fell through to ntfy's web page.
  v="$(sed -E 's/[[:space:]]+#.*$//' <<<"$v")"
  v="${v#\"}"; v="${v%\"}"; v="${v#\'}"; v="${v%\'}"; v="${v//[[:space:]]/}"
  printf '%s' "$v"
}

# sw_ntfy <title> <priority> <message>: POST to ntfy, prints the HTTP code only (never the URL). SW_CURL_BIN for tests.
sw_ntfy() {
  local topic code base
  topic="$(sw_topic)" || { printf '000'; return 1; }
  [ -n "$topic" ] || { echo "stuck-watch: no ntfy topic, phone disabled" >&2; printf '000'; return 1; }
  base="$(sw_val SW_NTFY_BASE ntfy_base)"
  code="$("${SW_CURL_BIN:-curl}" -s -o /dev/null -w '%{http_code}' --max-time 10 -H "Title: $1" -H "Priority: $2" -H "Tags: rotating_light" \
          --data-binary "$3" "$base/$topic" 2>/dev/null)" || code="${code:-000}"
  printf '%s' "${code:-000}"; [ "${code:-000}" = 200 ]
}

# sw_ntfy_poll <since-epoch>: the messages on the selected topic since then, one JSON line each, read back from ntfy
# (item 35 proof: a script reads the test topic; nothing is asked of the owner). Topic never printed.
sw_ntfy_poll() {
  local topic; topic="$(sw_topic)" && [ -n "$topic" ] || return 1
  "${SW_CURL_BIN:-curl}" -s --max-time 15 "$(sw_val SW_NTFY_BASE ntfy_base)/$topic/json?poll=1&since=$1" | jq -c 'select(.event=="message") | {id,time,title,priority,message}'
}

# sw_due <key>: exit 0 (and stamp) when key was not notified within dedupe_minutes. Idempotent across restarts: on disk.
sw_due() {
  local f now last win
  f="$(sw_state_dir)/notified.json"; [ -s "$f" ] || echo '{}' > "$f"
  now="$(date -u +%s)"; win=$(( $(sw_val SW_DEDUPE_MIN dedupe_minutes) * 60 ))
  last="$(jq -r --arg k "$1" '.[$k] // 0' "$f")"
  (( now - last >= win )) || return 1
  return 0
}
sw_stamp() { local f; f="$(sw_state_dir)/notified.json"; jq --arg k "$1" --argjson t "$(date -u +%s)" '.[$k]=$t' "$f" > "$f.tmp" && mv "$f.tmp" "$f"; }

# sw_evidence <seat> <code> <json>: the evidence file in the artifact store (item 23); prints its path.
sw_evidence() {
  local art f root d
  art="$SW_DIR/../../tools/artifact/artifact.sh"
  if [ -f "$art" ]; then
    f="$(bash "$art" new --key trace --name "stuck-$(sw_tok "$2")-$(sw_tok "$1" | cut -c1-24)" --ext json \
         --what "stuck-watch evidence $2 for seat $1" --by stuck-watch 2>/dev/null)" || f=""
  fi
  if [ -z "$f" ]; then
    root="$(sw_expand "${ARTIFACT_ROOT:-$HOME/.local/state/zenith}")"; d="$root/trace/$(date -u +%Y/%m)"; mkdir -p "$d"
    f="$d/$(date -u +%Y%m%d-%H%M%S)-stuck-$(sw_tok "$2")-$(sw_tok "$1" | cut -c1-24).json"
    [ -e "$f" ] && f="${f%.json}-$$.json"
    printf -- '---\nwhat: stuck-watch evidence %s for seat %s\nby: claude/workflow/stuck-watch\nat: %s\n---\n' "$2" "$1" "$(sw_now)" > "$f"
  fi
  printf '%s\n' "$3" >> "$f"; printf '%s' "$f"
}

# sw_js_get <request-json>: one JetStream STREAM.MSG.GET on the configured stream, request/reply over /dev/tcp. Prints the
# reply JSON ({"message":{subject,seq,data(base64),time}} or {"error":{code:404,...}}). Exit 2 when the bus is unreachable,
# so the deadman can tell "bus down" from "no heartbeat". SW_JS_GET_CMD replaces the transport (tests).
sw_js_get() {
  if [ -n "${SW_JS_GET_CMD:-}" ]; then $SW_JS_GET_CMD "$1"; return; fi
  local url host port stream line len body inbox="_INBOX.sw$$"
  url="$(sw_val SW_NATS_URL nats_url)"; host="${url%%:*}"; port="${url##*:}"; stream="$(sw_val SW_STREAM stream)"
  { exec 8<>"/dev/tcp/$host/$port"; } 2>/dev/null || return 2
  printf 'CONNECT {"verbose":false}\r\nSUB %s 1\r\nPUB $JS.API.STREAM.MSG.GET.%s %s %d\r\n%s\r\n' \
    "$inbox" "$stream" "$inbox" "$(printf '%s' "$1" | wc -c)" "$1" >&8
  while IFS= read -r -t 3 line <&8; do
    line="${line%$'\r'}"
    case "$line" in
      MSG\ *) len="${line##* }"; IFS= read -r -t 3 -N "$len" body <&8; exec 8>&-; printf '%s\n' "$body"; return 0 ;;
      PING*) printf 'PONG\r\n' >&8 ;;
    esac
  done
  exec 8>&-; return 2
}
# sw_b64 <base64>: decoded payload.
sw_b64() { printf '%s' "$1" | base64 -d 2>/dev/null; }
