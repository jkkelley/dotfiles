#!/usr/bin/env bash
# shellcheck disable=SC2016 # jq programs are single-quoted on purpose
# lib.sh - budgets, events and bottleneck work orders shared by bin/timed-run.sh, node-timing.sh and line-timing.sh.
# name: lib.sh
# purpose: budgets, start/end events, SLOW/TIMEOUT codes and bottleneck work orders for the timing tools
# inputs: config/time-budgets.json, TM_* env
# outputs: none (sourced)
# writes-to: NATS line.<line>.event.node.* and .timing.*, the bottlenecks work-order project
# cleanup: make timing-down; the work-order project is kept for the architect
# Sets no shell options (see bin/workflow-lib.sh BREADCRUMB). Reuses stuck-watch/lib.sh for the bus (sw_pub, sw_js_get).
#
# BREADCRUMB - bottleneck work orders go to their own work-order project in the state store, not to a repo checkout.
# What broke: nothing yet; the rejected alternative. A monitor running work-order.sh against ~/dotfiles would leave
#   untracked ticket files on whatever branch that checkout happens to be on, and two monitors would race its INDEX.md.
# Why this fix: wo_project (default ~/.local/state/zenith/bottlenecks) is a git repo this lib initialises once, with one
#   top-level epic; every SLOW or TIMEOUT files a child there, deduped per node+code per UTC day. The architect promotes
#   a child into the owning repo. Cost: the tickets are not in the owning repo until promoted.
TM_DIR="${TM_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
TM_BUDGETS="${TM_BUDGETS:-$TM_DIR/../config/time-budgets.json}"
# shellcheck source=stuck-watch/lib.sh disable=SC1091
. "$TM_DIR/../stuck-watch/lib.sh"

tm_cfg() { jq -r "$1" "$TM_BUDGETS"; }
# tm_limit <budget_s|timeout_s> <kind> <node>: nodes.<node> wins over kinds.<kind>, over default.
tm_limit() { jq -r --arg f "$1" --arg k "$2" --arg n "$3" '(.nodes[$n][$f] // .kinds[$k][$f] // .default[$f])' "$TM_BUDGETS"; }
tm_event() { # tm_event <line> <node> <kind> <run> <phase> [extra-json]: publishes line.<line>.event.node.<phase>
  local j x="${6:-}"; [ -n "$x" ] || x='{}'
  j="$(jq -nc --arg at "$(sw_now)" --arg l "$1" --arg n "$2" --arg k "$3" --arg r "$4" --arg p "$5" --argjson x "$x" \
    '{schema:"timing/event/1",at:$at,line:$l,node:$n,kind:$k,run_id:$r,phase:$p} + $x')"
  sw_pub "line.$(sw_tok "$1").event.node.$5" "$j" || echo "WARN bus unreachable, $5 of $2 not published" >&2
}
tm_code() { # tm_code <line> <SLOW|TIMEOUT> <evidence-json>: line.<line>.timing.<code>
  sw_pub "line.$(sw_tok "$1").timing.$2" "$(jq -c --arg c "$2" --arg at "$(sw_now)" '. + {schema:"timing/code/1",code:$c,at:$at}' <<<"$3")" \
    || echo "WARN bus unreachable, $2 not published" >&2
}

# tm_wo <node> <code> <evidence-json>: one bottleneck work order per node+code per UTC day; prints its id or "deduped".
tm_wo() {
  local proj wo epic key seen id
  proj="$(sw_expand "${TM_WO_PROJECT:-$(tm_cfg .wo_project)}")"; wo="${WO_BIN:-$TM_DIR/../../skills/work-order/scripts/work-order.sh}"
  key="$(date -u +%Y%m%d)/$1/$2"; seen="$(sw_state_dir)/timing-wo.json"; [ -s "$seen" ] || echo '{}' > "$seen"
  id="$(jq -r --arg k "$key" '.[$k] // empty' "$seen")"; [ -n "$id" ] && { printf 'deduped %s' "$id"; return 0; }
  mkdir -p "$proj" || return 1
  if [ ! -d "$proj/.git" ] && command -v git >/dev/null; then git -C "$proj" init -q && git -C "$proj" -c user.name=bottlenecks -c user.email=bottlenecks@localhost commit -q --allow-empty -m "bottlenecks: init"; fi
  epic="$(cat "$proj/.epic" 2>/dev/null)"
  if [ -z "$epic" ]; then
    epic="$(bash "$wo" new --project "$proj" --json --top-level --type feature --title "$(tm_cfg .wo_epic_title)" \
      --problem "Owner item 37: code that runs over budget is status SLOW and becomes a bottleneck work order." \
      --out "fixing the node here; each child is promoted to its owning repo" --ac "every child promoted or closed" --ac-check true --ac-exit 0 \
      --owner-words "Every DAG node, seat, job, CI run and merge records its start and end in UTC on the bus by script" --context "$(tm_cfg .wo_epic_title)" | jq -r .id)" || return 1
    printf '%s' "$epic" > "$proj/.epic"
  fi
  id="$(bash "$wo" new --project "$proj" --json --parent "$epic" --type bug --title "Bottleneck: $1 $2 ($(jq -r '"\(.duration_s // "?")s vs budget \(.budget_s // "?")s"' <<<"$3"))" \
    --problem "$(jq -c . <<<"$3")" --out "changing the budget without a ruling" --ac "node $1 runs inside its budget on three consecutive runs" --ac-check true --ac-exit 0 \
    --owner-words "Every DAG node, seat, job, CI run and merge records its start and end in UTC on the bus by script" --context "$(jq -c . <<<"$3")" | jq -r .id)" || return 1
  jq --arg k "$key" --arg v "$id" '.[$k]=$v' "$seen" > "$seen.tmp" && mv "$seen.tmp" "$seen"; printf '%s' "$id"
}
