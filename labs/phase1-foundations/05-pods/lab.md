# Lab 1.5: Pods

> **Phase:** 1 — Foundations | **Time:** ~30 min

## Objective

Understand pods as the atomic unit of Kubernetes — single-container, multi-container with sidecars, and init containers. Observe lifecycle phases hands-on.

## Background

A Pod is the smallest deployable unit in Kubernetes. It wraps one or more containers that share:
- The same network namespace (same IP address)
- The same PID namespace (can see each other's processes)
- Shared volumes

## Exercises

### 1. Single-container pod

```bash
kubectl apply -f simple-pod.yaml
kubectl get pod simple-pod
kubectl describe pod simple-pod
```

Watch the pod go through phases: `Pending → ContainerCreating → Running`.

```bash
kubectl get pod simple-pod -w &
sleep 15 && kill %1 2>/dev/null; true
```

### 2. Pod lifecycle phases

```bash
# Running
kubectl get pod simple-pod -o jsonpath='{.status.phase}'

# Succeeded — a pod that exits 0
kubectl apply -f succeeded-pod.yaml
kubectl get pod succeeded-pod     # shows Completed

# Failed — a pod that exits non-zero
kubectl apply -f failed-pod.yaml
kubectl get pod failed-pod        # shows Error or CrashLoopBackOff
kubectl logs failed-pod
```

### 3. Multi-container pod (sidecar pattern)

```bash
kubectl apply -f multi-container-pod.yaml
kubectl get pod multi-pod
```

Both containers share the same network namespace — the sidecar can reach the main container on `localhost`:

```bash
# Exec into the sidecar and curl the main container
kubectl exec -it multi-pod -c sidecar -- wget -qO- localhost:80 | head -3

# Each container has its own logs
kubectl logs multi-pod -c web
kubectl logs multi-pod -c sidecar
```

### 4. Init containers

```bash
kubectl apply -f init-pod.yaml
kubectl get pod init-pod -w &
```

Watch the pod progress: `Init:0/1 → Init:1/1 → PodInitializing → Running`.

```bash
# Check init container logs
kubectl logs init-pod -c init-check

# The main container only starts after init succeeds
kubectl exec -it init-pod -- cat /work-dir/ready.txt
```

### 5. Pod networking — every pod gets an IP

```bash
kubectl get pod -o wide
# Each pod has a unique cluster IP — this is from Calico's IPAM
```

Two pods can communicate via pod IP:

```bash
POD_IP=$(kubectl get pod simple-pod -o jsonpath='{.status.podIP}')
kubectl exec -it multi-pod -c web -- wget -qO- $POD_IP | head -3
```

### 6. Pod resource usage

```bash
kubectl top pod 2>/dev/null || echo "metrics-server may still be starting"
```

### 7. Delete a pod — there is no restart

```bash
kubectl delete pod simple-pod
kubectl get pod simple-pod   # Gone — pods are ephemeral
```

Pods are cattle, not pets. In production you never manage pods directly — you use Deployments.

## Cleanup

```bash
kubectl delete pod simple-pod succeeded-pod failed-pod multi-pod init-pod 2>/dev/null; true
```

## Interview cues

- **Q:** Why would you use a multi-container pod vs separate pods?  
  **A:** When containers need to share a localhost interface or a volume — e.g., a log-shipping sidecar reading files the main container writes, or a proxy that must intercept localhost traffic.

- **Q:** What's the difference between init containers and regular containers?  
  **A:** Init containers run to completion sequentially before any regular container starts. They're for setup tasks — waiting for a database, seeding a volume. If an init container fails, the pod restarts.

- **Q:** What are the pod lifecycle phases?  
  **A:** Pending (not yet scheduled or image pulling), Running (at least one container running), Succeeded (all containers exited 0), Failed (at least one container exited non-zero), Unknown (node communication lost).
