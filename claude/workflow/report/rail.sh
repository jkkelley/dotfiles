#!/usr/bin/env bash
# rail.sh - the only way this project's status page changes.
#
#   ./report/rail.sh log <step> <status> "<text, 15 words max>" [ref]   append a row, rebuild
#   ./report/rail.sh build                                             rebuild only
#   ./report/rail.sh show [n]                                          print the ledger
#   ./report/rail.sh approve                                           stamp the owner signal
#   ./report/rail.sh publish                                           put the built page in front of the owner
#   ./report/rail.sh surface                                           print which surface this seat publishes to
#
# BREADCRUMB - why a wrapper exists at all, rather than calling the vendored scripts directly.
# What broke: bin/ledger.sh takes its ledger path from RAIL_LEDGER. A seat that called it without
#   exporting that variable wrote to whatever the variable happened to hold, which in the upstream
#   copy was another project's ledger entirely (see the breadcrumb at bin/ledger.sh line 8).
# Why it mattered: the ledger is the only input the page is rendered from. A row in the wrong file
#   is a row that never reaches the page, and it corrupts the other project's record on the way past.
# Why this fix: one wrapper pins every path to this project and rebuilds after every append, so the
#   page cannot drift from the ledger and no seat ever types a path.
#   Rejected: exporting the variables from a shell rc, which holds until someone opens a second
#   terminal or a seat starts in a pane that did not source it.
# Cost: one more file per project. It is four lines of configuration and a case statement.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# BREADCRUMB - why this wrapper points at the template engine instead of a copy beside it.
# What differs: a scaffolded project gets its own copy of the engine in report/rail/, because it has no
#   dotfiles checkout to point at. Dotfiles is where that engine lives, so a second copy here would be two
#   engines in one repository that drift apart the first time one is fixed and the other is not.
# Rejected: copying rail/ beside this file to match a scaffolded project byte for byte.
# Cost: this one line differs from rail.sh.tmpl. The template is still the source; re-render and re-apply
#   this line if the template changes.
RAIL="$HERE/../../skills/project-scaffold/references/templates/rail"

# ---- this project, and nothing about any other -----------------------------
PROJECT="dotfiles"
TITLE="Dotfiles Orchestration"
EYEBROW="dotfiles · orchestration + scaffold loops · 2026-09-22"
SOURCE="HANDOFF-orchestration-surface.md, HANDOFF-scaffold-multiagent.md"

# Tracking never enters git: the ledger, the built page and the approval marker are state, not source.
# What is committed is plan.json, side.html and this wrapper - the inputs, never the render.
STATE="${RAIL_STATE_DIR:-$HOME/.local/state/$PROJECT/rail}"
mkdir -p "$STATE"

export RAIL_LEDGER="$STATE/ledger.tsv"
export RAIL_SEAT="${RAIL_SEAT:-${PROJECT}-seat}"
PLAN="$HERE/plan.json"
OUT="$STATE/page.html"

# ---- surface routing: which model is driving decides where the page goes ----
# BREADCRUMB - why the surface is read from the environment and never inferred by a model.
# What broke: a Kimi seat was asked for an owner-facing page and had no way to produce one. Kimi
#   cannot mint a claude.ai artifact URL - that URL comes from a Claude-only tool - so the seat
#   either invented a URL or silently produced nothing the owner could open.
# Why it mattered: a decision surface the owner cannot open is the same as no decision surface, and
#   an invented URL is worse, because it looks like success in the transcript.
# Why this fix: the spawner knows the runtime because the workflow declaration names it, so it
#   exports RAIL_SURFACE and this script routes on that value. Code answers, the model does not
#   guess. lavish serves a local 127.0.0.1 session URL any runtime can produce; the Artifact tool
#   produces a claude.ai URL only a Claude seat can.
#   Rejected: asking the model which surface it should use, which is a judgement call handed to the
#   one party with no reliable way to know, and which changes answer between runs.
# Cost: RAIL_SURFACE must be set at spawn. Unset falls back to lavish, which every runtime can open.
surface() {
  case "${RAIL_SURFACE:-}" in
    artifact|lavish) printf '%s' "$RAIL_SURFACE" ;;
    *) printf 'lavish' ;;
  esac
}

build() {
  local extra=()
  [ -f "$STATE/.approved" ] && extra+=(--approved)
  [ -f "$HERE/side.html" ] && extra+=(--side "$HERE/side.html")
  "$RAIL/bin/rail-build.sh" \
    --plan "$PLAN" --ledger "$RAIL_LEDGER" --out "$OUT" \
    --title "$TITLE" --eyebrow "$EYEBROW" --source "$SOURCE" "${extra[@]}" >/dev/null
  printf 'built %s\n' "$OUT"
}

# The page lives at ONE address for the life of the plan. A second address strands every link the
# owner already has, so the address is recorded in a file rather than left to whoever builds next.
publish() {
  build
  case "$(surface)" in
    lavish)
      command -v lavish-axi >/dev/null 2>&1 || { printf 'lavish-axi is not on PATH\n' >&2; exit 1; }
      lavish-axi "$OUT"
      printf 'surface: lavish. Poll for feedback in a labeled herdr pane, never in a background job.\n'
      ;;
    artifact)
      if [ -f "$HERE/ARTIFACT-URL" ]; then
        printf 'surface: artifact. Republish %s with the Artifact tool passing url=%s\n' "$OUT" "$(cat "$HERE/ARTIFACT-URL")"
      else
        printf 'surface: artifact. First publish: send %s with the Artifact tool, then write the returned URL to %s/ARTIFACT-URL\n' "$OUT" "$HERE"
      fi
      ;;
  esac
}

case "${1:-build}" in
  log)     shift; "$RAIL/bin/ledger.sh" "$@"; build ;;
  build)   build ;;
  show)    "$RAIL/bin/ledger.sh" --show "${2:-20}" ;;
  approve) : > "$STATE/.approved"; build ;;
  publish) publish ;;
  surface) surface; echo ;;
  *)       sed -n '3,9p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
