SHELL := /bin/bash
INSTANCE ?= riscv-virt-2hart
ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))

export ROOT

.PHONY: help check-host fetch verify-lock pin create build run sdk test test-sim bench clean

help: ## Show this help
	@awk 'BEGIN {FS = ":.*## "; printf "Usage: make <target> [INSTANCE=<name>] [ARGS=\"...\"]\n\nTargets (thin aliases for ./run.sh):\n"} /^[a-zA-Z_-]+:.*## / {printf "  %-14s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

check-host: ## Check host build dependencies
	@./run.sh check-host

fetch: ## Fetch pinned component sources into repos/
	@./run.sh fetch

verify-lock: ## Verify fetched sources match env/versions.toml
	@./run.sh verify-lock

pin: ## Pin a component: make pin COMPONENT=<name> REF=<ref|branch>
	@./run.sh pin $(COMPONENT) $(REF)

create: ## Materialize workspace/instances/$(INSTANCE)
	@./run.sh create $(INSTANCE)

build: ## Build or link artifacts for the instance
	@./run.sh build $(INSTANCE)

run: ## Run the instance; pass simulator args with ARGS="..."
	@./run.sh start $(INSTANCE) $(ARGS)

sdk: ## Package an SDK bundle from the instance
	@./run.sh sdk $(INSTANCE)

test: ## Run smoke tests
	@./run.sh test smoke

test-sim: ## Run simulator cargo tests
	@./run.sh test sim

bench: ## Benchmark the instance boot (pass ARGS="--runs 3")
	@./run.sh bench --instance $(INSTANCE) $(ARGS)

clean: ## Remove an instance workspace (keeps env/instances definition)
	@./run.sh clean --instance $(INSTANCE)
