# timing.mk - start and end of every node on the bus, durations against budgets, SLOW and TIMEOUT as work orders (item 37).
# Included by claude/workflow/Makefile. Inputs are VAR=value (item 17): LINE, SINCE, NODE, KIND, BUDGET, TIMEOUT, RETRIES, CMD.
# Budgets: config/time-budgets.json. Gates (item 34): timing-dev, timing-uat; stable is the monitors.json node-timing entry.
TM_HOME := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
TM_BOX  := $(shell jq -r .nats_box_image $(TM_HOME)/../herdr-bus/config.json)
TM_NATS := podman run --rm --network=host $(TM_BOX) nats --server nats://$(shell jq -r .nats_url $(TM_HOME)/../stuck-watch/config.json)
TM_BUCKET := $(shell jq -r .kv_bucket $(TM_HOME)/../config/time-budgets.json)
.PHONY: timing-up timing-down node-timing-loop line-timing morning-audit timed-run timing-test timing-dev timing-uat

timing-up: ## make timing-up: the TIMING KV bucket (idempotent); node-timing creates its own consumer
	@$(TM_NATS) kv info $(TM_BUCKET) >/dev/null 2>&1 || $(TM_NATS) kv add $(TM_BUCKET) --history 1 --ttl 30d >/dev/null
	@echo "kv $(TM_BUCKET) up"
timing-down: ## make timing-down: remove the node-timing consumer (the bucket and its history stay)
	@$(TM_NATS) consumer rm LINE $(shell jq -r .consumer $(TM_HOME)/../config/time-budgets.json) -f >/dev/null 2>&1 || true
	@echo "node-timing consumer removed"
node-timing-loop: timing-up ## the monitors.json entry: durable pull consumer, KV writes, SLOW and work orders
	@bash $(TM_HOME)/node-timing.sh
line-timing: ## make line-timing LINE= [SINCE=]: durations vs budgets and the top 5 bottlenecks, report in the artifact store
	$(if $(LINE),,$(error LINE= is required))
	@bash $(TM_HOME)/line-timing.sh --line "$(LINE)" $(if $(SINCE),--since "$(SINCE)")
morning-audit: ## make morning-audit LINE= [SINCE=]: stuck-audit then line-timing
	@$(MAKE) --no-print-directory stuck-audit LINE="$(LINE)" SINCE="$(SINCE)"
	@$(MAKE) --no-print-directory line-timing LINE="$(LINE)" SINCE="$(SINCE)"
timed-run: ## make timed-run NODE= [KIND= BUDGET= TIMEOUT= RETRIES= LINE=] CMD='...': any step, timed on the bus
	$(if $(NODE),,$(error NODE= is required))$(if $(CMD),,$(error CMD= is required))
	@bash $(TM_HOME)/../bin/timed-run.sh --node "$(NODE)" $(if $(KIND),--kind "$(KIND)") $(if $(LINE),--line "$(LINE)") \
	  $(if $(BUDGET),--budget $(BUDGET)) $(if $(TIMEOUT),--timeout $(TIMEOUT)) $(if $(RETRIES),--retries $(RETRIES)) -- bash -c '$(CMD)'
timing-test: image ## timed-run, node-timing, line-timing against stubs, --network=none [CASE=] (relevant test only)
	@$(RUN) bash -c 'shellcheck -x bin/timed-run.sh timing/*.sh timing/tests/*.sh && CASE="$(CASE)" bash timing/tests/test_timing.sh'
timing-dev: timing-test ## Gate 1 (item 34)
timing-uat: ## Gate 2: the real bus and KV: a slow node, a timed-out node, the report [LINE=timing-uat]
	@bash $(TM_HOME)/tests/uat.sh "$(or $(LINE),timing-uat)"
test: timing-test
