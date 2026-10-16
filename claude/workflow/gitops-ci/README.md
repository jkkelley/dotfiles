<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [gitops-ci](#gitops-ci)
  - [What it does](#what-it-does)
  - [Targets](#targets)
  - [Add a repository](#add-a-repository)
  - [Gate evidence](#gate-evidence)
  - [Fallbacks](#fallbacks)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# gitops-ci

## What it does

Diff-selected CI for any GitOps repository.
It runs yamllint, kubeconform, helm template and kustomize build on the changed paths only.
It also holds a deploy PR that lacks its dev and UAT gate evidence.

## Targets

Run as `make -f claude/workflow/gitops-ci/gitops-ci.mk <target> REPO=owner/name REPO_DIR=<checkout> BASE=<ref>`.

| Target            | Inputs                          | What it runs                                           | Exit codes                                                        |
| ----------------- | ------------------------------- | ------------------------------------------------------ | ----------------------------------------------------------------- |
| `gitops-select`   | REPO, REPO_DIR, BASE, SELECT    | bin/gitops-changed.sh, writes the selection JSON       | 0 ok, 1 check failed or gate held, 2 usage, 4 runtime or image missing |
| `gitops-check`    | as above                        | bin/gitops-check.sh on the selection                   | same                                                              |
| `gitops-gate`     | as above, BODY optional         | bin/gitops-gate-evidence.sh on the selection           | same                                                              |
| `gitops-ci-test`  | none                            | tests/gitops-ci.test.sh in the pinned test image       | same                                                              |
| `gitops-ci-clean` | none                            | removes the selection files                            | same                                                              |

## Add a repository

1. Add one entry under `repos` in `config/gitops-ci.json`.
2. Add a Makefile in the repo as in homelab-gitops.
3. Add one entry in `claude/workflow/pr-flow/config/pr-flow.json` and run `make -C claude/workflow pr-flow-ci-install REPO=owner/name`.

## Gate evidence

The PR body carries the lines `Ticket`, `Gate-Dev: GATE-PASS dev ...` and `Gate-UAT: GATE-PASS uat ...`.
A body edited after the event needs a pushed commit.

## Fallbacks

| Failure                      | Fallback                                                                              |
| ---------------------------- | ------------------------------------------------------------------------------------- |
| podman missing               | docker                                                                                |
| no runtime                   | exit 4 ENV-MISSING                                                                    |
| image pull fails 3 times     | exit 4 IMAGE-PULL, CI red, merge-on-green holds                                       |
| bus down                     | timed-run.sh warns and the step keeps its exit code                                   |
| merge-on-green refused       | `make -C claude/workflow pr-merge REPO= PR=`                                          |

GOOD: a PR changing apps/line-ops/base/deadman.yaml builds the line-ops base and both overlays and nothing else.
NEVER: a deploy PR merged with no Gate-Dev and Gate-UAT lines.
NEVER: a repo-specific copy of these scripts.
