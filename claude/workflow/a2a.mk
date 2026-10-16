# a2a.mk - Make targets for agent to agent briefs and results (schema, never prose; owner 2026-10-16).
#
# Standalone on purpose, run as: make -C claude/workflow -f a2a.mk brief-check FILE=<brief.json>
# BREADCRUMB - why this is not in claude/workflow/Makefile.
# What broke: nothing yet; PR 134 (ctx-guard) edits that Makefile, and Design principles 101 item 19 forbids two tickets
#   touching one file at once (architect ruling 2026-10-16).
# Why this fix: a new file cannot collide. Rejected: editing the Makefile and rebasing over 134, which is the collision.
# Cost: one line, `include a2a.mk`, plus `a2a-test` in the `test` prerequisites, moves into Makefile after 134 merges.
# Inputs are VAR=value (item 17). brief-check and result-check are the tools themselves and run on the host;
# a2a-test is verification and runs in Podman (Rule 14).
BRIEF_SH := $(CURDIR)/bin/brief.sh
A2A_IMAGE := localhost/dotfiles-workflow-test:1
A2A_ROOT := $(abspath $(CURDIR)/../..)
# BREADCRUMB - every recipe below runs through the shared timing wrapper (item 37, owner 2026-10-16 UTC:
#   "time out everything logically, you'll ID the bottlenecks"; WO-20261016-23b5).
# What broke: nothing yet; an untimed target is an invisible bottleneck, no start/end on the bus, no timeout.
# Why this fix: one prefix per recipe line; a down bus only warns (timed-run keeps the step's own exit code).
#   Rejected: a SHELL override, which would also time every recipe-internal shell call.
TIMED = bash $(abspath bin/timed-run.sh) --node $@ --kind make --

.PHONY: brief-new brief-check result-check brief-migrate a2a-test

brief-new: ## Build a brief: OUT= [CONFIG=] [ID= FROM= TO= SUBJECT= RESULT_FILE= DONE_TOKEN= AC='AC1|statement|kind|proof']
	@test -n "$(OUT)" || { echo "usage: make brief-new OUT=<file> [CONFIG=<file>] [ID= FROM= TO= SUBJECT= AC=...]" >&2; exit 2; }
	@$(TIMED) $(BRIEF_SH) new --out "$(OUT)" $(if $(CONFIG),--config "$(CONFIG)") $(if $(ID),--id "$(ID)") $(if $(FROM),--from "$(FROM)") \
	  $(if $(TO),--to "$(TO)") $(if $(SUBJECT),--subject "$(SUBJECT)") $(if $(RESULT_FILE),--result-file "$(RESULT_FILE)") \
	  $(if $(DONE_TOKEN),--done-token "$(DONE_TOKEN)") $(if $(AC),--ac "$(AC)")

brief-check: ## Validate a brief: FILE= [BUILD=1 [WO_PROJECT=<dir>]] (schema; BUILD=1 also needs a ready work order, else DESIGN-GAP exit 3)
	@test -n "$(FILE)" || { echo "usage: make brief-check FILE=<brief.json> [BUILD=1] [WO_PROJECT=<dir>]" >&2; exit 2; }
	@$(TIMED) $(BRIEF_SH) check "$(FILE)" $(if $(BUILD),--build) $(if $(WO_PROJECT),--wo-project "$(WO_PROJECT)")

result-check: ## Validate a result: FILE= [BRIEF=] (done, every AC ticked with proof)
	@test -n "$(FILE)" || { echo "usage: make result-check FILE=<result.json> [BRIEF=<brief.json>]" >&2; exit 2; }
	@$(TIMED) $(BRIEF_SH) result-check "$(FILE)" $(if $(BRIEF),--brief "$(BRIEF)")

brief-migrate: ## Upgrade an older brief: FILE= OUT=
	@test -n "$(FILE)" -a -n "$(OUT)" || { echo "usage: make brief-migrate FILE=<old> OUT=<new>" >&2; exit 2; }
	@$(TIMED) $(BRIEF_SH) migrate "$(FILE)" --out "$(OUT)"

a2a-test: ## The relevant tests only, in Podman
	@$(TIMED) podman run --rm --network=none --userns=keep-id -v "$(A2A_ROOT):/work:Z" -w /work/claude/workflow -e HOME=/tmp $(A2A_IMAGE) \
	  bash -c 'shellcheck -x bin/brief.sh tests/unit/test_a2a_brief.sh && bash tests/unit/test_a2a_brief.sh'
