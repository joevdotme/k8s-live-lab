include ../../common.mk

test:
	$(KUBECTL) wait --for=condition=Ready pod/simple-pod --timeout=$(TIMEOUT)
	@echo "[pods] simple-pod is Ready."
