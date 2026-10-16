# Root entry points. Each target is a thin include; the work lives in scripts.
include claude/tools/ctx-guard/ctx-guard.mk
include claude/tools/artifact/artifact.mk

# Contents lists on every Markdown file. Scripts drive it; nothing by hand.
BASE ?= origin/main
MAXLEVEL ?= 3
.PHONY: md-contents md-contents-check md-contents-global md-contents-global-check md-contents-discover

md-contents:            ## write contents lists (changed files; ALL=1 for everything)
	BASE=$(BASE) MAXLEVEL=$(MAXLEVEL) bash scripts/md-contents.sh write $(if $(ALL),--all)

md-contents-check:      ## fail on a missing or stale list (changed files; ALL=1 for everything)
	BASE=$(BASE) MAXLEVEL=$(MAXLEVEL) bash scripts/md-contents.sh check $(if $(ALL),--all)

md-contents-global:     ## write lists into the global files in config/md-contents-global.list (backs up first)
	bash scripts/md-contents.sh global

md-contents-global-check:
	bash scripts/md-contents.sh global --check

md-contents-discover:   ## print untracked global .md files missing from the list
	bash scripts/md-contents.sh discover

# Inputs are Make variables passed on, e.g. make golden-rules-repos PARALLEL=4 PROJECTS=~/projects
BRANCH ?= chore/golden-rules
PARALLEL ?= 8
PROJECTS ?= $(HOME)/projects
FROM ?= $(HOME)/AGENTS.md

.PHONY: golden-rules-global-check golden-rules golden-rules-extract golden-rules-check golden-rules-global golden-rules-repos

golden-rules-extract:   ## rebuild claude/golden-rules.md from FROM=<AGENTS.md> (owner rule edits only)
	bash scripts/golden-rules.sh extract $(FROM)


golden-rules: golden-rules-extract           ## write the golden rules block under the contents list of dotfiles' instruction files
	bash scripts/golden-rules.sh write

golden-rules-check:     ## fail when any copy drifts from claude/golden-rules.md
	bash scripts/golden-rules.sh check

golden-rules-global: golden-rules-extract    ## global instruction files (config/golden-rules.global), backed up first
	bash scripts/golden-rules.sh global

golden-rules-repos: golden-rules-extract     ## one branch + PR per git repo under ~/projects, in parallel (DRY=1 lists only)
	BRANCH=$(BRANCH) PARALLEL=$(PARALLEL) PROJECTS=$(PROJECTS) bash scripts/golden-rules.sh repos $(if $(DRY),--dry-run)

golden-rules-global-check:
	bash scripts/golden-rules.sh global --check
