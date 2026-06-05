include ../../common.mk

up:
	$(KUBECTL) apply -f namespaces.yaml
	$(KUBECTL) apply -f app-in-team-a.yaml
	$(KUBECTL) apply -f app-in-team-b.yaml

down:
	# Deleting the namespaces removes everything inside them.
	$(KUBECTL) delete namespace team-a team-b --ignore-not-found=true

test:
	$(KUBECTL) get pod web -n team-a
	$(KUBECTL) get pod web -n team-b
	@echo "[namespaces] Same pod name 'web' exists in both namespaces — isolation confirmed."
