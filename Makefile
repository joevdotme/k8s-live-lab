# Kubernetes Live Lab — root Makefile
#
# Cluster:  make cluster-up | cluster-down | cluster-status
# Lab:      make <name>-up  | <name>-down  | <name>-test  | <name>-reset
#
# Example:  make pods-up
#           make deployments-down
#           make cluster-up

KUBECTL     ?= kubectl
HELM        ?= helm
CLUSTER     ?= k8s-lab
KIND_CONFIG ?= kind-config.yaml

CALICO_URL       := https://raw.githubusercontent.com/projectcalico/calico/v3.27.3/manifests/calico.yaml
METRICS_SRV_URL  := https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
INGRESS_URL      := https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

.DEFAULT_GOAL := help

# ============================================================================
# Lab directory map — drives the %-up/down/test/reset pattern rules below.
# ============================================================================

LAB_what-is-k8s       := labs/phase1-foundations/01-what-is-kubernetes
LAB_control-plane     := labs/phase1-foundations/02-control-plane
LAB_node-components   := labs/phase1-foundations/03-node-components
LAB_kubectl-basics    := labs/phase1-foundations/04-kubectl-basics
LAB_pods              := labs/phase1-foundations/05-pods
LAB_yaml              := labs/phase1-foundations/06-yaml-manifests
LAB_namespaces        := labs/phase1-foundations/07-namespaces

LAB_deployments       := labs/phase2-workloads/01-deployments
LAB_replicasets       := labs/phase2-workloads/02-replicasets
LAB_statefulsets      := labs/phase2-workloads/03-statefulsets
LAB_daemonsets        := labs/phase2-workloads/04-daemonsets
LAB_jobs              := labs/phase2-workloads/05-jobs-cronjobs
LAB_resources         := labs/phase2-workloads/06-resource-requests-limits
LAB_probes            := labs/phase2-workloads/07-probes
LAB_configmaps        := labs/phase2-workloads/08-configmaps-secrets

LAB_services          := labs/phase3-networking-storage/01-services
LAB_endpoints         := labs/phase3-networking-storage/02-endpoints-selectors
LAB_dns               := labs/phase3-networking-storage/03-dns
LAB_ingress           := labs/phase3-networking-storage/04-ingress
LAB_netpol            := labs/phase3-networking-storage/05-network-policies
LAB_cni               := labs/phase3-networking-storage/06-cni-basics
LAB_pvcs              := labs/phase3-networking-storage/07-persistentvolumes-pvcs
LAB_storageclass      := labs/phase3-networking-storage/08-storageclass

LAB_rbac              := labs/phase4-production/01-rbac
LAB_serviceaccounts   := labs/phase4-production/02-service-accounts
LAB_pod-security      := labs/phase4-production/03-pod-security
LAB_hpa               := labs/phase4-production/04-hpa
LAB_affinity          := labs/phase4-production/05-node-affinity
LAB_taints            := labs/phase4-production/06-taints-tolerations
LAB_pdb               := labs/phase4-production/07-pdb
LAB_helm              := labs/phase4-production/08-helm

LAB_etcd              := labs/phase5-advanced/01-etcd
LAB_crds              := labs/phase5-advanced/02-crds
LAB_admission         := labs/phase5-advanced/03-admission-controllers
LAB_upgrades          := labs/phase5-advanced/04-cluster-upgrades
LAB_observability     := labs/phase5-advanced/05-observability
LAB_multitenancy      := labs/phase5-advanced/06-multi-tenancy
LAB_debugging         := labs/phase5-advanced/07-debugging
LAB_interview         := labs/phase5-advanced/08-interview-scenarios

# ============================================================================
# Cluster lifecycle
# ============================================================================

.PHONY: cluster-up cluster-down cluster-status install-calico install-metrics-server install-ingress-ctrl

cluster-up: ## Create 3-node kind cluster, install Calico + Metrics Server + Helm
	@echo "==> Creating kind cluster '$(CLUSTER)'..."
	kind create cluster --name $(CLUSTER) --config $(KIND_CONFIG)
	@echo "==> Installing Calico CNI..."
	$(KUBECTL) apply -f $(CALICO_URL)
	$(KUBECTL) -n kube-system wait --for=condition=Ready pod \
	  -l k8s-app=calico-node --timeout=180s
	@echo "==> Installing Metrics Server..."
	$(KUBECTL) apply -f $(METRICS_SRV_URL)
	$(KUBECTL) -n kube-system patch deployment metrics-server --type=json \
	  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
	@echo "==> Verifying nodes are Ready..."
	$(KUBECTL) wait --for=condition=Ready node --all --timeout=120s
	@echo "==> Cluster ready. Run 'make cluster-status' to verify."

cluster-down: ## Destroy the kind cluster
	kind delete cluster --name $(CLUSTER)

cluster-status: ## Show cluster health (nodes, system pods)
	@echo "==> Nodes"
	$(KUBECTL) get nodes -o wide
	@echo ""
	@echo "==> System pods"
	$(KUBECTL) get pods -n kube-system

install-calico: ## (Re)install Calico CNI
	$(KUBECTL) apply -f $(CALICO_URL)
	$(KUBECTL) -n kube-system wait --for=condition=Ready pod \
	  -l k8s-app=calico-node --timeout=180s

install-metrics-server: ## (Re)install Metrics Server
	$(KUBECTL) apply -f $(METRICS_SRV_URL)
	$(KUBECTL) -n kube-system patch deployment metrics-server --type=json \
	  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'

install-ingress-ctrl: ## Install nginx Ingress Controller for kind (needed for ingress lab)
	$(KUBECTL) apply -f $(INGRESS_URL)
	$(KUBECTL) -n ingress-nginx wait --for=condition=Ready pod \
	  -l app.kubernetes.io/component=controller --timeout=120s

# ============================================================================
# Pattern rules — delegate to the lab's own Makefile
# ============================================================================
# Usage:  make <lab-name>-up   (e.g.  make pods-up)
#         make <lab-name>-down
#         make <lab-name>-test
#         make <lab-name>-reset

%-up:
	@test -n "$(LAB_$*)" || { echo "Unknown lab '$*'. Run 'make help'."; exit 1; }
	$(MAKE) -C $(LAB_$*) up

%-down:
	@test -n "$(LAB_$*)" || { echo "Unknown lab '$*'. Run 'make help'."; exit 1; }
	$(MAKE) -C $(LAB_$*) down

%-test:
	@test -n "$(LAB_$*)" || { echo "Unknown lab '$*'. Run 'make help'."; exit 1; }
	$(MAKE) -C $(LAB_$*) test

%-reset:
	@test -n "$(LAB_$*)" || { echo "Unknown lab '$*'. Run 'make help'."; exit 1; }
	$(MAKE) -C $(LAB_$*) reset

# ============================================================================
# Phase aggregate targets — bring up / tear down a whole phase at once
# ============================================================================

.PHONY: phase1-up phase1-down phase2-up phase2-down \
        phase3-up phase3-down phase4-up phase4-down phase5-up phase5-down

phase1-up: what-is-k8s-up control-plane-up node-components-up \
           kubectl-basics-up pods-up yaml-up namespaces-up
phase1-down: namespaces-down yaml-down pods-down kubectl-basics-down \
             node-components-down control-plane-down what-is-k8s-down

phase2-up: deployments-up replicasets-up statefulsets-up daemonsets-up \
           jobs-up resources-up probes-up configmaps-up
phase2-down: configmaps-down probes-down resources-down jobs-down \
             daemonsets-down statefulsets-down replicasets-down deployments-down

phase3-up: services-up endpoints-up dns-up ingress-up \
           netpol-up cni-up pvcs-up storageclass-up
phase3-down: storageclass-down pvcs-down cni-down netpol-down \
             ingress-down dns-down endpoints-down services-down

phase4-up: rbac-up serviceaccounts-up pod-security-up hpa-up \
           affinity-up taints-up pdb-up helm-up
phase4-down: helm-down pdb-down taints-down affinity-down \
             hpa-down pod-security-down serviceaccounts-down rbac-down

phase5-up: etcd-up crds-up admission-up upgrades-up \
           observability-up multitenancy-up debugging-up interview-up
phase5-down: interview-down debugging-down multitenancy-down \
             observability-down upgrades-down admission-down crds-down etcd-down

# ============================================================================
# Help
# ============================================================================

.PHONY: help

help: ## Show this help
	@echo ""
	@echo "Usage: make <target>"
	@echo ""
	@echo "Cluster"
	@echo "  cluster-up              Create kind cluster (Calico + Metrics Server)"
	@echo "  cluster-down            Destroy cluster"
	@echo "  cluster-status          Node + pod health check"
	@echo "  install-ingress-ctrl    Install nginx ingress controller (for ingress lab)"
	@echo ""
	@echo "Lab targets:  make <name>-up | <name>-down | <name>-test | <name>-reset"
	@echo ""
	@printf "  %-22s %s\n" "Phase 1 — Foundations" "(Days 1-3)"
	@printf "  %-22s %s\n" "  what-is-k8s"       "Lab 1.1  — architecture exploration"
	@printf "  %-22s %s\n" "  control-plane"      "Lab 1.2  — API server, etcd, scheduler"
	@printf "  %-22s %s\n" "  node-components"    "Lab 1.3  — kubelet, kube-proxy, CRI"
	@printf "  %-22s %s\n" "  kubectl-basics"     "Lab 1.4  — get/describe/logs/exec/apply"
	@printf "  %-22s %s\n" "  pods"               "Lab 1.5  — single, multi-container, init"
	@printf "  %-22s %s\n" "  yaml"               "Lab 1.6  — manifests with kubectl explain"
	@printf "  %-22s %s\n" "  namespaces"         "Lab 1.7  — isolation and scoping"
	@echo ""
	@printf "  %-22s %s\n" "Phase 2 — Workloads"  "(Days 4-7)"
	@printf "  %-22s %s\n" "  deployments"        "Lab 2.1  — rolling updates, rollback"
	@printf "  %-22s %s\n" "  replicasets"        "Lab 2.2  — label selectors, self-healing"
	@printf "  %-22s %s\n" "  statefulsets"       "Lab 2.3  — stable IDs, ordered rollout"
	@printf "  %-22s %s\n" "  daemonsets"         "Lab 2.4  — one pod per node"
	@printf "  %-22s %s\n" "  jobs"               "Lab 2.5  — batch + CronJob"
	@printf "  %-22s %s\n" "  resources"          "Lab 2.6  — requests, limits, QoS classes"
	@printf "  %-22s %s\n" "  probes"             "Lab 2.7  — liveness, readiness, startup"
	@printf "  %-22s %s\n" "  configmaps"         "Lab 2.8  — env vars + volume mounts"
	@echo ""
	@printf "  %-22s %s\n" "Phase 3 — Networking" "(Days 8-12)"
	@printf "  %-22s %s\n" "  services"           "Lab 3.1  — ClusterIP, NodePort, LB"
	@printf "  %-22s %s\n" "  endpoints"          "Lab 3.2  — selector matching + debug"
	@printf "  %-22s %s\n" "  dns"                "Lab 3.3  — CoreDNS, FQDN resolution"
	@printf "  %-22s %s\n" "  ingress"            "Lab 3.4  — nginx controller + routing"
	@printf "  %-22s %s\n" "  netpol"             "Lab 3.5  — default-deny + allow rules"
	@printf "  %-22s %s\n" "  cni"                "Lab 3.6  — CNI inspection"
	@printf "  %-22s %s\n" "  pvcs"               "Lab 3.7  — PV, PVC, data persistence"
	@printf "  %-22s %s\n" "  storageclass"       "Lab 3.8  — dynamic provisioning"
	@echo ""
	@printf "  %-22s %s\n" "Phase 4 — Production" "(Days 13-17)"
	@printf "  %-22s %s\n" "  rbac"               "Lab 4.1  — Roles, Bindings, SA auth"
	@printf "  %-22s %s\n" "  serviceaccounts"    "Lab 4.2  — tokens, auto-mount, projected"
	@printf "  %-22s %s\n" "  pod-security"       "Lab 4.3  — PSA enforce/warn/audit"
	@printf "  %-22s %s\n" "  hpa"                "Lab 4.4  — autoscaling on CPU/memory"
	@printf "  %-22s %s\n" "  affinity"           "Lab 4.5  — node/pod affinity + spread"
	@printf "  %-22s %s\n" "  taints"             "Lab 4.6  — taints + tolerations"
	@printf "  %-22s %s\n" "  pdb"                "Lab 4.7  — disruption budgets + drain"
	@printf "  %-22s %s\n" "  helm"               "Lab 4.8  — install/upgrade/rollback"
	@echo ""
	@printf "  %-22s %s\n" "Phase 5 — Advanced"   "(Days 18-21)"
	@printf "  %-22s %s\n" "  etcd"               "Lab 5.1  — backup/restore"
	@printf "  %-22s %s\n" "  crds"               "Lab 5.2  — custom resource definitions"
	@printf "  %-22s %s\n" "  admission"          "Lab 5.3  — Kyverno webhooks"
	@printf "  %-22s %s\n" "  upgrades"           "Lab 5.4  — drain/cordon/upgrade flow"
	@printf "  %-22s %s\n" "  observability"      "Lab 5.5  — Prometheus + Grafana stack"
	@printf "  %-22s %s\n" "  multitenancy"       "Lab 5.6  — RBAC + netpol + quotas"
	@printf "  %-22s %s\n" "  debugging"          "Lab 5.7  — CrashLoop, Pending, OOM"
	@printf "  %-22s %s\n" "  interview"          "Lab 5.8  — scenario practice"
	@echo ""
	@printf "  %-22s %s\n" "Phase shortcuts" ""
	@printf "  %-22s %s\n" "  phase1-up/down"    "All Phase 1 labs"
	@printf "  %-22s %s\n" "  phase2-up/down"    "All Phase 2 labs"
	@printf "  %-22s %s\n" "  phase3-up/down"    "All Phase 3 labs (installs ingress ctrl)"
	@printf "  %-22s %s\n" "  phase4-up/down"    "All Phase 4 labs"
	@printf "  %-22s %s\n" "  phase5-up/down"    "All Phase 5 labs"
	@echo ""
