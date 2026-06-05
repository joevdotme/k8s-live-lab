# Lab 1.4: kubectl Basics

> **Phase:** 1 — Foundations | **Time:** ~25 min

## Objective

Build kubectl muscle memory — get, describe, logs, exec, apply, delete, and output formatting. These commands come up in every interview and daily work.

## Background

`kubectl` talks to the Kubernetes API server. Virtually everything you do in Kubernetes goes through it. The pattern is: `kubectl <verb> <resource> [name] [flags]`.

## Exercises

### 1. Get — list resources

The active context is `default` — the right namespace for all lab work. Nothing has been deployed there yet, so the first command returns empty. That's expected; system components (Calico, CoreDNS, Metrics Server) live in `kube-system`, not `default`.

```bash
# List pods in the current namespace (empty until you deploy something)
kubectl get pods

# List pods in all namespaces
kubectl get pods -A

# Wide output (shows node, IP)
kubectl get pods -A -o wide

# Watch mode — updates live
kubectl get pods -w

# Get by label
kubectl get pods -l k8s-app=calico-node -A
```

### 2. Describe — deep dive on one resource

```bash
# Create a pod to practice on
kubectl run nginx --image=nginx --restart=Never

# Describe it — shows Events, which is essential for debugging
kubectl describe pod nginx
```

In the output find: `Status`, `IP`, `Node`, `Containers`, `Conditions`, `Events`.

The **Events** section at the bottom is the most useful for debugging problems.

### 3. Logs — read container output

```bash
# Basic logs
kubectl logs nginx

# Follow live logs
kubectl logs nginx -f

# Last N lines
kubectl logs nginx --tail=5

# Show timestamps
kubectl logs nginx --timestamps=true

# Previous container (after a crash)
kubectl logs nginx --previous 2>/dev/null || echo "no previous container yet"
```

### 4. Exec — run commands inside a container

```bash
# One-off command
kubectl exec nginx -- ls /etc/nginx/

# Interactive shell
kubectl exec -it nginx -- bash

# Inside the shell:
cat /etc/nginx/nginx.conf
curl -s localhost:80 | head -5
exit
```

### 5. Apply — declarative resource management

```bash
# apply creates or updates — the idiomatic way to manage resources
kubectl apply -f practice-pod.yaml

# Diff before applying
kubectl diff -f practice-pod.yaml 2>/dev/null || true
```

### 6. Delete resources

```bash
# Delete by name
kubectl delete pod nginx

# Delete via manifest file
kubectl delete -f practice-pod.yaml 2>/dev/null

# Force-delete a stuck pod (use sparingly)
# kubectl delete pod <name> --force --grace-period=0
```

### 7. Output formats

```bash
kubectl run info-pod --image=nginx --restart=Never
kubectl get pod info-pod -o yaml     # full YAML spec
kubectl get pod info-pod -o json     # JSON
kubectl get pod info-pod -o jsonpath='{.status.podIP}'  # extract one field
kubectl get pod info-pod -o jsonpath='{.spec.containers[0].image}'
kubectl get pods -o custom-columns=NAME:.metadata.name,IP:.status.podIP,NODE:.spec.nodeName
```

### 8. Explain — built-in API docs

```bash
# Explain any resource type
kubectl explain pod
kubectl explain pod.spec
kubectl explain pod.spec.containers
kubectl explain pod.spec.containers.resources

# Use this instead of Googling field names during an interview
```

### 9. Context and namespace

```bash
kubectl config current-context
kubectl config get-contexts

# Set a default namespace so you don't have to type -n every time:
kubectl config set-context --current --namespace=default
```

### 10. Port-forward — local access to a pod

```bash
kubectl run pf-test --image=nginx --restart=Never
kubectl wait --for=condition=Ready pod/pf-test

# Forward local port 8888 to pod port 80
kubectl port-forward pod/pf-test 8888:80 &
curl -s localhost:8888 | head -3
kill %1 2>/dev/null; true
```

## Cleanup

```bash
kubectl delete pod nginx info-pod pf-test 2>/dev/null; true
kubectl delete -f practice-pod.yaml 2>/dev/null; true
```

## Interview cues

- **Q:** What's the difference between `kubectl apply` and `kubectl create`?  
  **A:** `apply` is declarative — it creates if missing, updates if existing, and tracks the last-applied config. `create` fails if the resource already exists. Use `apply` for everything in production.

- **Q:** How do you debug a pod that keeps crashing?  
  **A:** `kubectl describe pod <name>` for events/conditions, `kubectl logs <name> --previous` for the last crash's logs.

- **Q:** How do you extract a single field from a pod's JSON?  
  **A:** `kubectl get pod <name> -o jsonpath='{.status.podIP}'` — jsonpath is cleaner than `| jq` when you're on a cluster without jq.
