SHELL := /bin/sh

.DEFAULT_GOAL := help

include docker/casa/version.env
export CASA_VERSION

COMPOSE ?= docker compose
PYTHON ?= python3
DEV_SERVICE := dev
CASA_SERVICE := casa

# Detect the available container runtime.
# Prefer Docker but fall back to Apptainer (HPC mode).
# Override explicitly with RUNTIME=docker or RUNTIME=apptainer if needed.
RUNTIME ?= $(shell command -v docker >/dev/null 2>&1 && echo docker || echo apptainer)

ifeq ($(RUNTIME),docker)
  RUN_DEV  = $(COMPOSE) run --rm $(DEV_SERVICE)
  RUN_CASA = $(COMPOSE) run --rm $(CASA_SERVICE)
else
  RUN_DEV  = ./apptainer/run-dev.sh
  RUN_CASA = ./apptainer/run-casa.sh
endif

UNIT_PATH ?= pipeline/pipeline
COMPONENT_PATH ?= pipeline/tests/component
REGRESSION_FAST_PATH ?= pipeline/tests/regression/fast
REGRESSION_PATH ?= pipeline/tests/regression
PYTEST_CACHE ?= /tmp/.pytest_cache
PYTEST_ARGS ?=

.PHONY: \
	help \
	bootstrap \
	build-dev \
	test-unit \

help:
	@printf "%s\n" \
	"Workspace commands (runtime: $(RUNTIME)):" \
	"  make bootstrap             Validate workspace prerequisites and print next steps" \
	"  make build-dev             Build the development image  (Docker only)" \
	"  make test-unit             Run the default fast unit-style path in dev" \

bootstrap:
	@$(PYTHON) scripts/bootstrap.py

ifeq ($(RUNTIME),docker)
build-dev:
	$(COMPOSE) build $(DEV_SERVICE)
else
build-dev:
	@printf "%s\n" \
	"build-dev requires Docker, which is not available in this environment." \
	"Build the SIF on a Docker machine and transfer it:" \
	"  ./apptainer/build.sh --dev" >&2
	@exit 1
endif

test-unit:
	$(RUN_DEV) \
		pytest $(UNIT_PATH) --nologfile -o "cache_dir=$(PYTEST_CACHE)" -q $(PYTEST_ARGS)
