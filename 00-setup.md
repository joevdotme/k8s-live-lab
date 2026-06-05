# Lab 0: Cluster Setup

> **Time:** ~20 min | Do this once before any other lab.

## What you'll set up

A 3-node kind cluster (1 control-plane, 2 workers) with Calico CNI and Metrics Server, using the repo's `Makefile` to drive the process.

## Prerequisites

Install these before running anything:

- **Docker** — `kind` runs clusters as containers

  ```bash
  # Install prerequisites
  sudo apt-get install -y ca-certificates curl gnupg

  # Add Docker's official GPG key
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

  # Set up the repository
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

  # Install Docker Engine and Compose
  sudo apt-get update
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  # Add user to docker group to run without sudo
  sudo usermod -aG docker $USER
  newgrp docker
  ```

- **kind** — Kubernetes in Docker

  ```bash
  curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.23.0/kind-linux-amd64
  chmod +x ./kind && sudo mv ./kind /usr/local/bin/kind
  kind version
  ```

- **kubectl** — the Kubernetes CLI

  ```bash
  curl -LO "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  chmod +x kubectl && sudo mv kubectl /usr/local/bin/kubectl
  kubectl version --client
  ```

- **Helm** — needed for Phase 4 + 5 labs

  ```bash
  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  helm version
  ```

- **make** — should already be present; verify with `make --version`

- **jq** — JSON processor used throughout the labs to extract specific fields from `kubectl -o json` output. `kubectl` can produce jsonpath and custom-columns output natively, but piping through `jq` is faster for ad-hoc inspection (e.g. pulling a pod's IP, reading a specific annotation, or diffing two objects).

  ```bash
  sudo apt-get install -y jq
  jq --version
  ```

---

## Create the cluster

From the repo root:

```bash
make cluster-up
```

That's it. This takes about 2–3 minutes. When it finishes, all nodes will be `Ready`.

---

## What `cluster-up` does (step by step)

The target in the root `Makefile` runs these steps in order:

### 1. `kind create cluster --name k8s-lab --config kind-config.yaml`

Spins up three Docker containers that act as Kubernetes nodes. The `kind-config.yaml` at the repo root configures the topology:

```yaml
nodes:
- role: control-plane
  extraPortMappings:          # exposes ports 80/443 → localhost:8080/8443
  - containerPort: 80         # needed for the Ingress lab
    hostPort: 8080
  - containerPort: 443
    hostPort: 8443
- role: worker
- role: worker
networking:
  disableDefaultCNI: true     # don't install kindnet — we want Calico instead
  podSubnet: "192.168.0.0/16" # Calico expects this subnet
```

After this step the nodes are `NotReady` — no CNI is installed yet, so pods can't communicate.

### 2. `kubectl apply -f <calico.yaml>` + wait

Installs [Calico](https://docs.tigera.io/calico/latest/about/) as the CNI (Container Network Interface) plugin. CNI is what gives each pod its IP address and routes traffic between pods across nodes.

**Why Calico and not kindnet (the default)?**  
NetworkPolicy enforcement requires a CNI that supports it. kindnet doesn't. Calico does — the NetworkPolicy lab (3.5) won't work without it.

The wait step blocks until all `calico-node` pods report `Ready`, which means the network fabric is up.

### 3. `kubectl apply -f <metrics-server.yaml>` + patch

Installs [Metrics Server](https://github.com/kubernetes-sigs/metrics-server), which collects CPU and memory usage from kubelets. The HPA lab (4.4) requires it — HPA can't compute utilization percentages without resource metrics.

The `--kubelet-insecure-tls` patch is needed because kind's kubelets use self-signed certificates that Metrics Server would otherwise reject.

### 4. Node readiness check

Waits for all three nodes to show `Ready` before declaring success.

---

## Verify

```bash
make cluster-status
```

You should see three `Ready` nodes and all system pods `Running` or `Completed`.

```
NAME                    STATUS   ROLES           AGE
k8s-lab-control-plane   Ready    control-plane   3m
k8s-lab-worker          Ready    <none>          3m
k8s-lab-worker2         Ready    <none>          3m
```

---

## Useful aliases

Add to `~/.bashrc` or `~/.zshrc`:

```bash
alias k=kubectl
alias kgp='kubectl get pods'
alias kgs='kubectl get svc'
alias kgn='kubectl get nodes'
complete -o default -F __start_kubectl k
```

---

## Ingress controller (Phase 3 only)

The Ingress lab needs an nginx controller that isn't part of `cluster-up` (it's heavyweight and only needed for one lab). Install it when you reach lab 3.4:

```bash
make install-ingress-ctrl
```

---

## Teardown

When you're done with all labs:

```bash
make cluster-down
```

This deletes the kind cluster and all its containers. Your local Docker images are preserved.
