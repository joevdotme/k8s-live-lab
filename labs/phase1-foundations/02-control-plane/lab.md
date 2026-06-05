# Lab 1.2: Control Plane Components

> **Phase:** 1 — Foundations | **Time:** ~20 min

## Objective

Inspect each control-plane component in a running cluster — understand what each process does and what breaks if it stops.

## Background

The four control-plane components:
- **API server** — HTTP REST frontend for all cluster operations; validates + stores to etcd
- **etcd** — distributed key-value store; cluster's source of truth
- **scheduler** — watches for unscheduled pods, assigns them to nodes
- **controller manager** — runs all built-in controllers (ReplicaSet, Node, Deployment, etc.) in one process

## Exercises

### 1. Find all control-plane pods

```bash
kubectl get pods -n kube-system -l tier=control-plane -o wide
```

All four components should be here, all on the control-plane node.

### 2. Inspect the API server

```bash
kubectl describe -n kube-system \
  $(kubectl get pods -n kube-system -l component=kube-apiserver -o name | head -1)
```

Look at the **Args** section — find:
- `--etcd-servers` — where is etcd?
- `--service-cluster-ip-range` — the CIDR for Service IPs
- `--authorization-mode` — typically `Node,RBAC`

### 3. Inspect etcd

```bash
kubectl describe -n kube-system \
  $(kubectl get pods -n kube-system -l component=etcd -o name | head -1)
```

Look for:
- `--data-dir` — where etcd stores data on disk
- `--listen-peer-urls` — cluster communication port (2380)
- `--listen-client-urls` — API server connects here (2379)

### 4. Inspect the scheduler

```bash
kubectl describe -n kube-system \
  $(kubectl get pods -n kube-system -l component=kube-scheduler -o name | head -1)
```

The scheduler watches for pods with `spec.nodeName: ""` and decides placement.

Check its logs to see scheduling decisions:

```bash
kubectl logs -n kube-system \
  $(kubectl get pods -n kube-system -l component=kube-scheduler -o name | head -1) \
  --tail=20
```

### 5. Inspect the controller manager

```bash
kubectl describe -n kube-system \
  $(kubectl get pods -n kube-system -l component=kube-controller-manager -o name | head -1)
```

The `--controllers` flag lists all the built-in controllers it runs. Common ones: `replicaset`, `deployment`, `node`, `serviceaccount`, `namespace`.

### 6. Watch the scheduler work

Create a pod and watch the scheduler assign it:

```bash
kubectl run scheduler-test --image=nginx --restart=Never &
kubectl get events --watch --field-selector reason=Scheduled 2>/dev/null &
sleep 3 && kubectl get pod scheduler-test -o wide
kill %2 2>/dev/null; true
```

You should see an event like `Successfully assigned default/scheduler-test to k8s-lab-worker`.

### 7. Understand the reconciliation loop

Create a deployment, then delete its pod manually and watch the controller manager reconcile:

```bash
kubectl create deployment reconcile-test --image=nginx --replicas=1
kubectl get pod -l app=reconcile-test

# Delete the pod — controller manager will recreate it
POD=$(kubectl get pod -l app=reconcile-test -o name | head -1)
kubectl delete $POD

# Watch it come back
kubectl get pod -l app=reconcile-test -w &
sleep 10 && kill %1 2>/dev/null; true
```

This is the core control loop: *observe → diff → act*.

## Cleanup

```bash
kubectl delete pod scheduler-test 2>/dev/null
kubectl delete deployment reconcile-test 2>/dev/null
```

## Interview cues

- **Q:** What does the controller manager do?  
  **A:** It runs all built-in Kubernetes controllers in a single process. Each controller watches the API server for its resource type and reconciles actual state toward desired state — e.g., the ReplicaSet controller ensures the right number of pod replicas exist at all times.

- **Q:** What happens if the scheduler crashes?  
  **A:** Existing pods keep running unaffected. New pods remain in `Pending` state (unscheduled) until the scheduler recovers.

- **Q:** Why does etcd use port 2379 and 2380?  
  **A:** 2379 is the client port (API server talks here). 2380 is the peer port (etcd nodes talk to each other for Raft consensus). In a single-node control plane you still see both configured.
