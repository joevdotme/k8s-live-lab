# Lab 1.7: Namespaces

> **Phase:** 1 — Foundations | **Time:** ~20 min

## Objective

Create namespaces, deploy resources into them, and observe how namespaces provide logical isolation for names, network policies, and RBAC.

## Background

A namespace is a virtual cluster inside a physical cluster. Resource names only need to be unique within a namespace. Key system namespaces: `default` (where your stuff goes if you don't specify), `kube-system` (control plane + addons), `kube-public` (publicly readable), `kube-node-lease` (node heartbeats).

## Exercises

### 1. View existing namespaces

```bash
kubectl get namespaces
kubectl get ns   # short form
```

Note: `kube-system` is where all control-plane components run.

### 2. Create namespaces

```bash
kubectl apply -f namespaces.yaml
kubectl get ns
```

### 3. Deploy the same name in different namespaces

```bash
kubectl apply -f app-in-team-a.yaml
kubectl apply -f app-in-team-b.yaml

# Both have a pod named "web" — no conflict because different namespaces
kubectl get pod -n team-a
kubectl get pod -n team-b
kubectl get pod -A -l app=web   # see both across all namespaces
```

### 4. Resources are namespace-scoped vs cluster-scoped

```bash
# Namespace-scoped: pods, deployments, services, configmaps, secrets...
kubectl api-resources --namespaced=true | head -15

# Cluster-scoped: nodes, namespaces, PersistentVolumes, ClusterRoles...
kubectl api-resources --namespaced=false | head -15
```

Nodes and Namespaces themselves are cluster-scoped — they don't live inside a namespace.

### 5. Default namespace shortcut

```bash
# Set a namespace as your current default (avoid typing -n every time)
kubectl config set-context --current --namespace=team-a
kubectl get pods   # now queries team-a by default

# Confirm
kubectl config view --minify | grep namespace

# Switch back
kubectl config set-context --current --namespace=default
```

### 6. Cross-namespace communication via DNS

Pods in different namespaces can talk to each other by using the full DNS name:
`<service-name>.<namespace>.svc.cluster.local`

(DNS lab in Phase 3 covers this in depth.)

### 7. Delete a namespace — deletes everything inside it

```bash
# Don't run this yet — we need these for demo
# kubectl delete namespace team-a
# All pods, services, configmaps in team-a would be deleted

# Instead just observe what's in team-a
kubectl get all -n team-a
```

## Cleanup

```bash
kubectl delete namespace team-a team-b --wait=false 2>/dev/null; true
```

## Interview cues

- **Q:** What is a namespace good for?  
  **A:** Logical isolation of resources — separate teams, environments (dev/staging), or projects in one cluster. Names only need to be unique within a namespace. You layer RBAC and NetworkPolicies on top to enforce isolation.

- **Q:** Are all resources namespace-scoped?  
  **A:** No. Cluster-scoped resources (Nodes, PersistentVolumes, ClusterRoles, Namespaces themselves) exist at the cluster level. `kubectl api-resources --namespaced=false` lists them.

- **Q:** What's in `kube-system`?  
  **A:** All cluster-level infrastructure: etcd, API server, scheduler, controller-manager, CoreDNS, kube-proxy, CNI pods. You generally don't put application workloads there.
