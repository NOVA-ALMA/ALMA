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

.PHONY: \
	help \
	bootstrap \

help:
	@printf "%s\n" \
	"Workspace commands (runtime: $(RUNTIME)):" \
	"  make bootstrap             Validate workspace prerequisites and print next steps" \

