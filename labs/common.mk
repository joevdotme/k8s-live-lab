# common.mk — included by every lab Makefile.
# Provides default up/down/wait/test/reset targets.
# Override any target in the lab's own Makefile.

KUBECTL  ?= kubectl
HELM     ?= helm
NS       ?= default
TIMEOUT  ?= 120s
CLUSTER  ?= k8s-lab

# ---- helpers ---------------------------------------------------------------

# Apply every .yaml in the current directory.
define kubectl-apply
	$(KUBECTL) apply -f . --namespace=$(NS)
endef

# Delete every .yaml in the current directory (no error if already gone).
define kubectl-delete
	$(KUBECTL) delete -f . --namespace=$(NS) --ignore-not-found=true 2>/dev/null; true
endef

# Wait for all pods in NS to become Ready.
define wait-ready
	$(KUBECTL) wait --for=condition=Ready pod --all \
	  --namespace=$(NS) --timeout=$(TIMEOUT) 2>/dev/null; true
endef

# ---- default targets -------------------------------------------------------
# Labs override these as needed.

.PHONY: up down wait test reset

up:
	@if ls *.yaml 2>/dev/null | grep -q .; then \
	  $(KUBECTL) apply -f . --namespace=$(NS); \
	else \
	  echo "[$(notdir $(CURDIR))] Observation-only lab — no resources to create."; \
	  echo "Open lab.md and follow the exercises."; \
	fi

down:
	@if ls *.yaml 2>/dev/null | grep -q .; then \
	  $(KUBECTL) delete -f . --namespace=$(NS) --ignore-not-found=true 2>/dev/null; true; \
	else \
	  echo "[$(notdir $(CURDIR))] Nothing to clean up."; \
	fi

wait:
	$(call wait-ready)

test:
	@echo "[$(notdir $(CURDIR))] No smoke test defined for this lab."

reset: down up
