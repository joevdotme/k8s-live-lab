# Lab 1.1: What is Kubernetes?

> **Phase:** 1 — Foundations | **Time:** ~15 min

## Objective

Explore a running cluster to validate the architecture in your head: control plane separates from workers, all state lives in etcd, and the API server is the single entry point.

## Background

Kubernetes orchestrates containers across a fleet of machines. The **control plane** (API server, etcd, scheduler, controller manager) runs the brain; **worker nodes** run the actual workloads via kubelet + container runtime. Every `kubectl` command is an API call to the API server.

## Exercises

### 1. Map the cluster

```bash
kubectl cluster-info
kubectl get nodes -o wide
```

Identify: which node is the control plane? What OS/kernel version? What container runtime?

### 2. Count the control-plane components

```bash
kubectl get pods -n kube-system
```

Find pods for: `etcd`, `kube-apiserver`, `kube-scheduler`, `kube-controller-manager`. These only run on the control-plane node.

Also find: `calico-node`, `kube-proxy` — these run on **every** node (they're DaemonSets).

### 3. Verify API server is the entry point

```bash
# Every kubectl call hits the API server. Watch it in action:
kubectl get --raw /healthz
kubectl get --raw /version
kubectl api-resources | head -20
```

`/healthz` returns `ok`. `/version` shows the Kubernetes version. `api-resources` is the full list of object types the cluster understands.

### 4. Explore what etcd stores

etcd holds all cluster state. You can't query it directly, but everything `kubectl get` returns comes from etcd.

```bash
# This is your window into etcd — all objects in the cluster:
kubectl get all -A
```

### 5. Check component health

```bash
kubectl get componentstatuses 2>/dev/null || echo "deprecated in newer clusters"
# Newer way:
kubectl get pods -n kube-system -l tier=control-plane
```

### 6. Describe a node to see full status

```bash
NODE=$(kubectl get nodes --no-headers | head -1 | awk '{print $1}')
kubectl describe node $NODE
```

Scroll through and note:
- **Capacity** vs **Allocatable** (some capacity is reserved for system)
- **Conditions** (MemoryPressure, DiskPressure, PIDPressure, Ready)
- **System Info** — kernel version, OS, container runtime
- **Non-terminated Pods** — what's scheduled here

### 7. Practice the 30-second explanation

Out loud (seriously), explain Kubernetes as if asked in an interview:

> "Kubernetes is a container orchestration platform. You declare the desired state — 'run 3 copies of this container' — and Kubernetes continuously reconciles actual state toward that desired state. The control plane (API server, scheduler, controller manager, etcd) makes decisions; worker nodes (kubelet + container runtime) execute them."

## Interview cues

- **Q:** What is the role of the API server?  
  **A:** It's the single entry point for all cluster operations — kubectl, controllers, and nodes all communicate through it. It validates and persists state to etcd.

- **Q:** What lives in etcd?  
  **A:** All cluster state: every object (pods, services, deployments, secrets, etc.) serialized as key-value pairs. It's the source of truth — losing etcd without a backup = losing the cluster.

- **Q:** What happens if the control plane goes down?  
  **A:** Running workloads keep running (kubelet is autonomous), but no new scheduling, no rolling updates, no config changes until the control plane recovers.
