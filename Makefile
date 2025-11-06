# Targets that should not be treated as positional arguments.
RESERVED_GOALS := test help list
.DEFAULT_GOAL := help

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

ROBOT ?= robot
ROBOT_SUITE ?= tests/api/service-lifecycle.robot
ROBOT_OUTPUT_DIR ?= robot_results

AUTH_EXAMPLE := $(firstword $(AUTH_OPTIONS))
CLUSTER_EXAMPLE := $(firstword $(CLUSTER_OPTIONS))
CLUSTER_EXAMPLE_DISPLAY := $(if $(CLUSTER_EXAMPLE),$(if $(filter cluster-%,$(CLUSTER_EXAMPLE)),$(patsubst cluster-%,%,$(CLUSTER_EXAMPLE)),$(CLUSTER_EXAMPLE)))

ifeq ($(filter test,$(MAKECMDGOALS)),test)
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

.PHONY: test help list

test:
	@echo "Auth config: $(AUTH_FILE)"
	@echo "Cluster config: $(CLUSTER_FILE)"
	$(ROBOT) -V $(AUTH_FILE) -V $(CLUSTER_FILE) -d $(ROBOT_OUTPUT_DIR) $(ROBOT_SUITE)

help:
	@echo "Usage:"
	@echo "  make test auth-<auth config> <cluster config>"
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
	@echo ""
endif
	@echo "Notes:"
	@echo "  - Auth targets correspond to filenames like variables/.env-auth-*.yaml (keep the auth- prefix)."
	@echo "  - Cluster targets can be used with or without the cluster- prefix."
	@echo ""
	@echo "Optional overrides:"
	@echo "  ROBOT=<robot command> (default: $(ROBOT))"
	@echo "  ROBOT_SUITE=<suite path> (default: $(ROBOT_SUITE))"
	@echo "  ROBOT_OUTPUT_DIR=<dir> (default: $(ROBOT_OUTPUT_DIR))"

list:
	@echo "Available auth configurations:"
	@$(if $(AUTH_OPTIONS),printf '  %s\n' $(AUTH_OPTIONS),echo '  (none found)')
	@echo ""
	@echo "Available cluster configurations:"
	@$(if $(CLUSTER_OPTIONS),printf '  %s\n' $(CLUSTER_OPTIONS),echo '  (none found)')
