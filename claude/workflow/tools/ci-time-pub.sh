#!/usr/bin/env bash
# name: ci-time-pub.sh
# purpose: STEP_TIME_PUB command for GitHub runners: append a step-time record to a JSONL file instead of the bus
# inputs: argv <subject> <json>; env CI_TIME_FILE (required)
# outputs: none; exit 2 on wrong argument count
# writes-to: $CI_TIME_FILE, one JSON line {subject,payload} per call
# cleanup: none; the runner is discarded after the job, the file is uploaded as artifact step-time-<shard>
#
# Breadcrumb: GitHub runners cannot reach the local NATS bus, so bin/step-time.sh cannot publish from CI. The file
# is the Design principles 101 item 28 fallback (bus down: file queue). It is uploaded as artifact
# step-time-<shard> and imported to the bus by the C1b ticket (ORD-0715).
set -euo pipefail
[ $# -eq 2 ] || { echo "usage: ci-time-pub.sh <subject> <json>" >&2; exit 2; }
jq -nc --arg s "$1" --argjson p "$2" '{subject:$s,payload:$p}' >>"${CI_TIME_FILE:?CI_TIME_FILE is required}"
