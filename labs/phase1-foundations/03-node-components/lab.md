# Lab 1.3: Node Components

> **Phase:** 1 — Foundations | **Time:** ~15 min

## Objective

Identify and understand kubelet, kube-proxy, and the container runtime on worker nodes — the three things that make a node a Kubernetes node.

## Background

Every node runs:
- **kubelet** — agent that receives pod specs from the API server and manages the container lifecycle via the CRI
- **kube-proxy** — maintains iptables/ipvs rules for Service → Pod routing
- **container runtime** — executes containers (containerd, CRI-O, Docker Engine)

## Exercises

### 1. List nodes with full details

```bash
kubectl get nodes -o wide
```

The `CONTAINER-RUNTIME` column shows what's running (likely `containerd://1.x.x`).

### 2. Describe a worker node

```bash
# Get a worker node name
WORKER=$(kubectl get nodes --no-headers | grep -v control-plane | head -1 | awk '{print $1}')
kubectl describe node $WORKER
```

Find in the output:
- **System Info** → Container Runtime Version (e.g., `containerd://1.7.x`)
- **Capacity / Allocatable** — total vs schedulable CPU/memory
- **Conditions** — `Ready`, `MemoryPressure`, `DiskPressure`, `PIDPressure`

### 3. Find kube-proxy

kube-proxy runs as a DaemonSet (one pod per node):

```bash
kubectl get daemonset -n kube-system kube-proxy
kubectl get pods -n kube-system -l k8s-app=kube-proxy -o wide
```

Check one pod's logs:

```bash
kubectl logs -n kube-system \
  $(kubectl get pods -n kube-system -l k8s-app=kube-proxy -o name | head -1) \
  --tail=10
```

### 4. Understand kubelet (runs as a systemd service in kind)

kubelet doesn't run as a pod — it's a system process. In kind, it runs inside the node container:

```bash
# Shell into a worker node container
docker exec -it $WORKER bash

# Inside the node:
systemctl status kubelet
journalctl -u kubelet --no-pager -n 20
ls /var/lib/kubelet/pods/     # pod storage on this node
exit
```

### 5. See what kubelet manages

Each pod gets a directory under `/var/lib/kubelet/pods/`:

```bash
docker exec -it $WORKER ls /var/lib/kubelet/pods/
```

### 6. Explore the CRI socket

kubelet talks to containerd via a Unix socket:

```bash
docker exec -it $WORKER bash -c "ls -la /run/containerd/containerd.sock"
# Or check crictl (CRI CLI):
docker exec -it $WORKER crictl pods
docker exec -it $WORKER crictl ps
```

`crictl` is like `docker ps` but talks directly to the container runtime (bypasses Kubernetes).

### 7. Node conditions and what they mean

```bash
kubectl get nodes -o json | \
  jq -r '["NODE","CONDITION","STATUS","REASON"],
         (.items[] | .metadata.name as $node | .status.conditions[]
          | [$node, .type, .status, .reason])
         | @tsv' \
  | column -t -s $'\t'
```

| Condition | True = bad | False = ok? |
|-----------|-----------|-------------|
| MemoryPressure | Node is low on memory | Normal |
| DiskPressure | Node is low on disk | Normal |
| PIDPressure | Node is low on process IDs | Normal |
| Ready | **True = healthy** | False = node problem |

## Interview cues

- **Q:** What is the kubelet's job?  
  **A:** It's the node agent. It watches the API server for pods assigned to its node, then manages the full container lifecycle: pulling images, starting/stopping containers via the CRI, running probes, and reporting status back to the API server.

- **Q:** What does kube-proxy do?  
  **A:** It programs the node's networking (iptables or ipvs) to implement Service routing. When a Service's ClusterIP is hit, kube-proxy's rules redirect traffic to one of the backing pods.

- **Q:** What is the CRI?  
  **A:** Container Runtime Interface — a standard gRPC API between kubelet and the container runtime. It lets Kubernetes support any runtime (containerd, CRI-O) without kubelet caring about implementation details.
