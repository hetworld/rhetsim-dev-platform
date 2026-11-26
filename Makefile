SHELL := /bin/bash
INSTANCE ?= riscv-virt-2hart
ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))

export ROOT

.PHONY: help check-host fetch create build run sdk test clean

help: ## Show this help
	@awk 'BEGIN {FS = ":.*## "; printf "Usage: make <target> [INSTANCE=<name>] [ARGS=\"...\"]\n\nTargets (thin aliases for ./run.sh):\n"} /^[a-zA-Z_-]+:.*## / {printf "  %-14s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

check-host: ## Check host build dependencies
	@./run.sh check-host

fetch: ## Fetch pinned component sources into repos/
	@./run.sh fetch

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

clean: ## Remove an instance workspace (keeps env/instances definition)
	@./run.sh clean --instance $(INSTANCE)
