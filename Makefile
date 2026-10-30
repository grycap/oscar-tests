# Targets that should not be treated as positional arguments.
RESERVED_GOALS := test test-parallel py-test docker-test help list clean-results clean-scalability-results
.DEFAULT_GOAL := help

# Recipes use bash-only features (e.g. ${var//search/replace}); /bin/sh may be
# dash on some systems, which fails with "Bad substitution".
SHELL := /bin/bash

OTHER_GOALS := $(filter-out $(RESERVED_GOALS),$(MAKECMDGOALS))
$(foreach goal,$(OTHER_GOALS),$(eval .PHONY: $(goal)))
$(foreach goal,$(OTHER_GOALS),$(eval $(goal): ; @:))

AUTH_GOAL := $(firstword $(filter auth-%,$(OTHER_GOALS)))
ifeq ($(AUTH_GOAL),)
  AUTH_GOAL := $(firstword $(OTHER_GOALS))
endif
CLUSTER_GOALS := $(filter-out $(AUTH_GOAL),$(OTHER_GOALS))
CLUSTER_GOAL := $(firstword $(CLUSTER_GOALS))

AUTH_INPUT := $(patsubst auth-%,%,$(AUTH_GOAL))
CLUSTER_INPUT := $(patsubst cluster-%,%,$(CLUSTER_GOAL))

AUTH_CONFIGS := $(sort $(notdir $(wildcard variables/.env-auth-*.yaml)))
CLUSTER_CONFIGS := $(sort $(notdir $(wildcard variables/.env-cluster-*.yaml)))

AUTH_OPTIONS := $(patsubst .env-%,%,$(AUTH_CONFIGS:.yaml=))
CLUSTER_OPTIONS := $(patsubst .env-%,%,$(CLUSTER_CONFIGS:.yaml=))

AUTH_SLUG := $(AUTH_INPUT)
CLUSTER_SLUG := $(CLUSTER_INPUT)

AUTH_FILE := $(if $(AUTH_SLUG),$(wildcard variables/.env-$(AUTH_SLUG).yaml))
ifeq ($(AUTH_FILE),)
  AUTH_FILE := $(if $(AUTH_SLUG),$(wildcard variables/.env-auth-$(AUTH_SLUG).yaml))
endif
AUTH_FILE := $(strip $(AUTH_FILE))

CLUSTER_FILE := $(if $(CLUSTER_SLUG),$(wildcard variables/.env-$(CLUSTER_SLUG).yaml))
ifeq ($(CLUSTER_FILE),)
  CLUSTER_FILE := $(if $(CLUSTER_SLUG),$(wildcard variables/.env-cluster-$(CLUSTER_SLUG).yaml))
endif
CLUSTER_FILE := $(strip $(CLUSTER_FILE))

SUITE_LIST := $(shell find tests -type f -name '*.robot' | sort)

ROBOT ?= $(if $(wildcard .venv/bin/robot),.venv/bin/robot,robot)
ROBOT_SUITE ?= tests/api/service-lifecycle.robot
ROBOT_ARGS ?=
ROBOT_OUTPUT_DIR ?= robot_results
ROBOT_ENV := $(if $(filter localhost,$(CLUSTER_INPUT)),PYTHONWARNINGS="ignore:Unverified HTTPS request is being made",)

AUTH_EXAMPLE := $(firstword $(AUTH_OPTIONS))
CLUSTER_EXAMPLE := $(firstword $(CLUSTER_OPTIONS))
CLUSTER_EXAMPLE_DISPLAY := $(if $(CLUSTER_EXAMPLE),$(if $(filter cluster-%,$(CLUSTER_EXAMPLE)),$(patsubst cluster-%,%,$(CLUSTER_EXAMPLE)),$(CLUSTER_EXAMPLE)))

ifneq ($(filter test test-parallel,$(MAKECMDGOALS)),)
  ifeq ($(AUTH_GOAL),)
    $(error Missing auth configuration. Usage: make test auth-<auth> <cluster>)
  endif
  ifeq ($(CLUSTER_GOAL),)
    $(error Missing cluster configuration. Usage: make test auth-<auth> <cluster>)
  endif
  ifeq ($(AUTH_FILE),)
    $(error No configuration file found for auth '$(AUTH_INPUT)'; checked variables/.env-$(AUTH_SLUG).yaml and variables/.env-auth-$(AUTH_SLUG).yaml)
  endif
  ifeq ($(CLUSTER_FILE),)
    $(error No configuration file found for cluster '$(CLUSTER_INPUT)'; checked variables/.env-$(CLUSTER_SLUG).yaml and variables/.env-cluster-$(CLUSTER_SLUG).yaml)
  endif
endif

.PHONY: test test-parallel py-test docker-test help list clean-results clean-scalability-results

test:
	@echo "Auth config: $(AUTH_FILE)"
	@echo "Cluster config: $(CLUSTER_FILE)"
	@echo "Robot suite: $(ROBOT_SUITE)"
	@echo "Robot args: $(ROBOT_ARGS)"
ifneq ($(ROBOT_SUITE),all)
	OSCAR_TEST_AUTH_GOAL="$(AUTH_GOAL)" \
	OSCAR_TEST_CLUSTER_GOAL="$(CLUSTER_GOAL)" \
	OSCAR_TEST_AUTH_FILE="$(AUTH_FILE)" \
	OSCAR_TEST_CLUSTER_FILE="$(CLUSTER_FILE)" \
	OSCAR_TEST_ROBOT="$(ROBOT)" \
	OSCAR_TEST_ROBOT_SUITE="$(ROBOT_SUITE)" \
	OSCAR_TEST_ROBOT_ARGS="$(ROBOT_ARGS)" \
	OSCAR_TEST_ROBOT_OUTPUT_DIR="$(ROBOT_OUTPUT_DIR)" \
	$(ROBOT_ENV) $(ROBOT) -V $(AUTH_FILE) -V $(CLUSTER_FILE) $(ROBOT_ARGS) -d $(ROBOT_OUTPUT_DIR) $(ROBOT_SUITE)
else
	@echo "Running all Robot test suites found under tests/."
	@if [ -z "$(strip $(SUITE_LIST))" ]; then \
	  echo "No Robot suites (*.robot) found under tests/"; \
	  exit 1; \
	fi
	@set -e; \
	for suite in $(SUITE_LIST); do \
	  rel="$${suite#tests/}"; \
	  dir_suffix="$${rel%.robot}"; \
	  safe_dir="$${dir_suffix//\//-}"; \
	  out_dir="$(ROBOT_OUTPUT_DIR)/$${safe_dir}"; \
	  echo "-> $$suite (output: $$out_dir)"; \
	  mkdir -p "$$out_dir"; \
	  OSCAR_TEST_AUTH_GOAL="$(AUTH_GOAL)" \
	  OSCAR_TEST_CLUSTER_GOAL="$(CLUSTER_GOAL)" \
	  OSCAR_TEST_AUTH_FILE="$(AUTH_FILE)" \
	  OSCAR_TEST_CLUSTER_FILE="$(CLUSTER_FILE)" \
	  OSCAR_TEST_ROBOT="$(ROBOT)" \
	  OSCAR_TEST_ROBOT_SUITE="$$suite" \
	  OSCAR_TEST_ROBOT_ARGS="$(ROBOT_ARGS)" \
	  OSCAR_TEST_ROBOT_OUTPUT_DIR="$$out_dir" \
	  $(ROBOT_ENV) $(ROBOT) -V $(AUTH_FILE) -V $(CLUSTER_FILE) $(ROBOT_ARGS) -d "$$out_dir" "$$suite"; \
	done
endif

PYTEST_SUITE ?= tests/python_tests/

# API suites safe to run concurrently: they use random service/bucket names
# (or disjoint fixed names) and per-suite artifact directories, so they do not
# collide with each other.
PARALLEL_API_SUITES := \
  tests/api/deployment.robot \
  tests/api/volumes.robot \
  tests/api/bucket-presign.robot \
  tests/api/orchestration.robot \
  tests/api/system-metrics.robot \
  tests/api/service-lifecycle-exposed.robot \
  tests/api/reserved-environment.robot \
  tests/api/system-logs.robot \
  tests/api/delete-not-own.robot \
  tests/api/isolation.robot \
  tests/api/visibility.robot \
  tests/api/service-lifecycle.robot \
  tests/api/delete-not-own-service.robot \
  tests/api/buckets.robot \
  tests/api/mount_cycle.robot \
  tests/api/service-update.robot \
  tests/api/federation.robot

# API suites that must run serially: they temporarily reduce global (MinIO) or
# user memory quotas, so anything else deploying services or creating buckets
# at the same time would fail spuriously.
SERIAL_API_SUITES := \
  tests/api/quotas-user.robot \
  tests/api/minio-quotas.robot

# Runs the API suites in two waves: wave 1 launches all PARALLEL_API_SUITES at
# once (one worker per suite); wave 2 runs SERIAL_API_SUITES one by one. Each
# suite writes its own output under $(ROBOT_OUTPUT_DIR)/tests-api-<suite>.
# Does not stop on the first failure: the exit status is 1 with full logs in ROBOT_OUTPUT_DIR.
test-parallel:
	@echo "Auth config: $(AUTH_FILE)"
	@echo "Cluster config: $(CLUSTER_FILE)"
	@echo "Wave 1 (parallel, $(words $(PARALLEL_API_SUITES)) suites): $(PARALLEL_API_SUITES)"
	@echo "Wave 2 (serial, $(words $(SERIAL_API_SUITES)) suites): $(SERIAL_API_SUITES)"
	@echo "Robot args: $(ROBOT_ARGS)"
	@set -e; \
	pids=""; failed=0; \
	for suite in $(PARALLEL_API_SUITES); do \
	  rel="$${suite#tests/}"; \
	  dir_suffix="$${rel%.robot}"; \
	  safe_dir="$${dir_suffix//\//-}"; \
	  out_dir="$(ROBOT_OUTPUT_DIR)/$${safe_dir}"; \
	  mkdir -p "$$out_dir"; \
	  echo "-> [wave 1, parallel] $$suite (output: $$out_dir)"; \
	  OSCAR_TEST_AUTH_GOAL="$(AUTH_GOAL)" \
	  OSCAR_TEST_CLUSTER_GOAL="$(CLUSTER_GOAL)" \
	  OSCAR_TEST_AUTH_FILE="$(AUTH_FILE)" \
	  OSCAR_TEST_CLUSTER_FILE="$(CLUSTER_FILE)" \
	  OSCAR_TEST_ROBOT="$(ROBOT)" \
	  OSCAR_TEST_ROBOT_SUITE="$$suite" \
	  OSCAR_TEST_ROBOT_ARGS="$(ROBOT_ARGS)" \
	  OSCAR_TEST_ROBOT_OUTPUT_DIR="$$out_dir" \
	  $(ROBOT_ENV) $(ROBOT) -V $(AUTH_FILE) -V $(CLUSTER_FILE) -v ARTIFACTS_DIR:"$$out_dir/artifacts" $(ROBOT_ARGS) -d "$$out_dir" "$$suite" & \
	  pids="$$pids $$!"; \
	done; \
	for pid in $$pids; do \
	  if ! wait "$$pid"; then \
	    failed=1; \
	  fi; \
	done; \
	for suite in $(SERIAL_API_SUITES); do \
	  rel="$${suite#tests/}"; \
	  dir_suffix="$${rel%.robot}"; \
	  safe_dir="$${dir_suffix//\//-}"; \
	  out_dir="$(ROBOT_OUTPUT_DIR)/$${safe_dir}"; \
	  mkdir -p "$$out_dir"; \
	  echo "-> [wave 2, serial] $$suite (output: $$out_dir)"; \
	  OSCAR_TEST_AUTH_GOAL="$(AUTH_GOAL)" \
	  OSCAR_TEST_CLUSTER_GOAL="$(CLUSTER_GOAL)" \
	  OSCAR_TEST_AUTH_FILE="$(AUTH_FILE)" \
	  OSCAR_TEST_CLUSTER_FILE="$(CLUSTER_FILE)" \
	  OSCAR_TEST_ROBOT="$(ROBOT)" \
	  OSCAR_TEST_ROBOT_SUITE="$$suite" \
	  OSCAR_TEST_ROBOT_ARGS="$(ROBOT_ARGS)" \
	  OSCAR_TEST_ROBOT_OUTPUT_DIR="$$out_dir" \
	  $(ROBOT_ENV) $(ROBOT) -V $(AUTH_FILE) -V $(CLUSTER_FILE) -v ARTIFACTS_DIR:"$$out_dir/artifacts" $(ROBOT_ARGS) -d "$$out_dir" "$$suite" || failed=1; \
	done; \
	if [ "$$failed" -ne 0 ]; then \
	  echo "test-parallel: some suites failed. Logs in $(ROBOT_OUTPUT_DIR)"; \
	fi; \
	exit $$failed

py-test:
	@echo "Auth config: $(AUTH_FILE)"
	@echo "Cluster config: $(CLUSTER_FILE)"
	@echo "Python suite: $(PYTEST_SUITE)"
	PYTHONPATH=tests/python_tests \
	OSCAR_TEST_AUTH_GOAL="$(AUTH_GOAL)" \
	OSCAR_TEST_CLUSTER_GOAL="$(CLUSTER_GOAL)" \
	OSCAR_TEST_AUTH_FILE="$(AUTH_FILE)" \
	OSCAR_TEST_CLUSTER_FILE="$(CLUSTER_FILE)" \
	python3 -m pytest $(PYTEST_SUITE) -v --tb=short

docker-test:
	@echo "Building Docker image..."
	docker build -t oscar-tests .
	@echo ""
	@echo "Running all tests inside the container..."
	docker run --rm -i \
	  -v "$(PWD):/workspace" \
	  -w /workspace \
	  oscar-tests \
	  bash -c '\
	    echo "=== Installing oscar-cli ==="; \
	    go install github.com/grycap/oscar-cli/v2@v2.1.0; \
	    echo ""; \
	    echo "=== Installing oscar-python ==="; \
	    pip install --no-cache-dir oscar-python==2.1.0; \
	    echo ""; \
	    $(if $(filter command line,$(origin PYTEST_SUITE)),\
	      echo "=== Running Python tests ==="; \
	      PATH=$$PATH:/root/go/bin make py-test $(AUTH_GOAL) $(CLUSTER_GOAL) PYTEST_SUITE="$(PYTEST_SUITE)"; \
	      echo "exit code: $$?"; \
	    ,\
	      echo "=== Skipping Python tests (set PYTEST_SUITE to run) ==="; \
	    ) \
	    echo ""; \
	    $(if $(filter command line,$(origin ROBOT_SUITE)),\
	      echo "=== Running CLI Robot tests ==="; \
	      PATH=$$PATH:/root/go/bin make test $(AUTH_GOAL) $(CLUSTER_GOAL) ROBOT_SUITE="$(ROBOT_SUITE)"; \
	      echo "exit code: $$?"; \
	    ,\
	      echo "=== Skipping Robot tests (set ROBOT_SUITE to run) ==="; \
	    )'

clean-results:
	@if [ -z "$(strip $(ROBOT_OUTPUT_DIR))" ] || [ "$(ROBOT_OUTPUT_DIR)" = "/" ]; then \
	  echo "Refusing to remove unsafe ROBOT_OUTPUT_DIR='$(ROBOT_OUTPUT_DIR)'"; \
	  exit 1; \
	fi
	@echo "Removing Robot results: $(ROBOT_OUTPUT_DIR)"
	rm -rf "$(ROBOT_OUTPUT_DIR)"

clean-scalability-results:
	@if [ -z "$(strip $(ROBOT_OUTPUT_DIR))" ] || [ "$(ROBOT_OUTPUT_DIR)" = "/" ]; then \
	  echo "Refusing to remove unsafe ROBOT_OUTPUT_DIR='$(ROBOT_OUTPUT_DIR)'"; \
	  exit 1; \
	fi
	@echo "Removing scalability results: $(ROBOT_OUTPUT_DIR)/scalability"
	rm -rf "$(ROBOT_OUTPUT_DIR)/scalability"

help:
	@echo "Usage:"
	@echo "  make test auth-<auth config> <cluster config>"
	@echo "  make test-parallel auth-<auth config> <cluster config>"
	@echo "  make clean-results"
	@echo "  make clean-scalability-results"
	@echo ""
	@echo "Available auth configurations:"
	@$(if $(AUTH_OPTIONS),printf '  %s\n' $(AUTH_OPTIONS),echo '  (none found)')
	@echo ""
	@echo "Available cluster configurations:"
	@$(if $(CLUSTER_OPTIONS),printf '  %s\n' $(CLUSTER_OPTIONS),echo '  (none found)')
	@echo ""
ifneq ($(and $(AUTH_EXAMPLE),$(CLUSTER_EXAMPLE)),)
	@echo "Example:"
	@echo "  make test $(AUTH_EXAMPLE) $(CLUSTER_EXAMPLE_DISPLAY)"
	@echo "  make test $(AUTH_EXAMPLE) $(CLUSTER_EXAMPLE_DISPLAY) ROBOT_SUITE=all"
	@echo "  make py-test $(AUTH_EXAMPLE) $(CLUSTER_EXAMPLE_DISPLAY)"
	@echo "  make docker-test $(AUTH_EXAMPLE) $(CLUSTER_EXAMPLE_DISPLAY)"
	@echo ""
endif
	@echo "Notes:"
	@echo "  - Auth targets correspond to filenames like variables/.env-auth-*.yaml (keep the auth- prefix)."
	@echo "  - Cluster targets can be used with or without the cluster- prefix."
	@echo ""
	@echo "Optional overrides:"
	@echo "  ROBOT=<robot command> (default: $(ROBOT))"
	@echo "  ROBOT_SUITE=<suite path> (default: $(ROBOT_SUITE), use 'all' for all suites)"
	@echo "  ROBOT_ARGS=<extra Robot args, e.g. -v NAME:value>"
	@echo "  ROBOT_OUTPUT_DIR=<dir> (default: $(ROBOT_OUTPUT_DIR))"
	@echo "  PARALLEL_API_SUITES / SERIAL_API_SUITES=<suites> (test-parallel waves)"
	@echo "  PYTEST_SUITE=<path or pattern> (default: $(PYTEST_SUITE))"
	@echo ""
	@echo "Cleanup:"
	@echo "  make clean-results              Remove $(ROBOT_OUTPUT_DIR)"
	@echo "  make clean-scalability-results  Remove $(ROBOT_OUTPUT_DIR)/scalability"

list:
	@echo "Available auth configurations:"
	@$(if $(AUTH_OPTIONS),printf '  %s\n' $(AUTH_OPTIONS),echo '  (none found)')
	@echo ""
	@echo "Available cluster configurations:"
	@$(if $(CLUSTER_OPTIONS),printf '  %s\n' $(CLUSTER_OPTIONS),echo '  (none found)')
