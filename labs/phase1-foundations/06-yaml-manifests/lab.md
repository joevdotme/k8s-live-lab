# Lab 1.6: YAML Manifests

> **Phase:** 1 — Foundations | **Time:** ~20 min

## Objective

Write Kubernetes YAML manifests from scratch using `kubectl explain` as your reference. Understand every top-level field and how `spec` drives `status`.

## Background

Every Kubernetes object has four top-level fields:
- **apiVersion** — which API group/version owns this type
- **kind** — the object type (Pod, Deployment, Service...)
- **metadata** — name, namespace, labels, annotations
- **spec** — desired state (you write this)
- **status** — actual state (Kubernetes writes this — never put it in your YAML)

## Exercises

### 1. Use kubectl explain as live documentation

```bash
# Top-level fields of a Pod
kubectl explain pod

# Drill into spec
kubectl explain pod.spec

# Drill into containers
kubectl explain pod.spec.containers

# Any field, any depth
kubectl explain pod.spec.containers.resources.requests
```

`--recursive` shows the full tree:

```bash
kubectl explain pod.spec --recursive | head -40
```

### 2. Write a pod manifest by hand

Open a file called `my-pod.yaml` and write it without looking at examples — use `kubectl explain` only:

```bash
cat > my-pod.yaml << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: my-pod
  namespace: default
  labels:
    app: my-app
    env: lab
spec:
  containers:
  - name: app
    image: nginx:alpine
    ports:
    - containerPort: 80
    env:
    - name: MY_VAR
      value: "hello"
EOF
kubectl apply -f my-pod.yaml
kubectl get pod my-pod
```

### 3. Understand what --dry-run generates

Use dry-run to scaffold YAML — handy in interviews when you don't want to write everything:

```bash
# Generate a pod manifest without creating it
kubectl run generated --image=nginx --dry-run=client -o yaml

# Save it to a file and customize
kubectl run generated --image=nginx --dry-run=client -o yaml > generated-pod.yaml
```

### 4. Generate manifests for other resources

```bash
kubectl create deployment my-dep --image=nginx --replicas=2 --dry-run=client -o yaml
kubectl create service clusterip my-svc --tcp=80:80 --dry-run=client -o yaml
kubectl create configmap my-cfg --from-literal=key1=val1 --dry-run=client -o yaml
kubectl create secret generic my-secret --from-literal=password=s3cr3t --dry-run=client -o yaml
```

This pattern (generate → edit → apply) is the fastest way to create any resource.

### 5. Validate a manifest before applying

```bash
kubectl apply -f my-pod.yaml --dry-run=server
```

`--dry-run=server` sends the manifest to the API server for validation but doesn't persist it. Catches more errors than `--dry-run=client`.

### 6. Diff before applying changes

Edit `my-pod.yaml` — change the image to `nginx:1.25`:

```bash
sed -i 's/nginx:alpine/nginx:1.25/' my-pod.yaml
kubectl diff -f my-pod.yaml
kubectl apply -f my-pod.yaml
```

### 7. Read back what's running

```bash
# Get the full live YAML (includes status, which you never write)
kubectl get pod my-pod -o yaml

# Strip managed fields for cleaner output
kubectl get pod my-pod -o yaml | grep -v managedFields
```

Notice `status` — it's entirely managed by Kubernetes. Your `spec` is the input; `status` is the output.

## Cleanup

```bash
kubectl delete pod my-pod --wait=false 2>/dev/null; true
rm -f my-pod.yaml generated-pod.yaml
```

## Interview cues

- **Q:** What is the difference between `spec` and `status`?  
  **A:** `spec` is what you declare as desired state — you write it. `status` is what Kubernetes observes as actual state — it writes it. The control loop continuously reconciles status toward spec.

- **Q:** How do you find the correct field name for a resource?  
  **A:** `kubectl explain <resource>.<path>` — it's the authoritative in-cluster reference. Never guess field names.

- **Q:** What does `apiVersion: apps/v1` mean vs `apiVersion: v1`?  
  **A:** `v1` is the core API group (pods, services, configmaps). `apps/v1` is the `apps` API group. The format is `<group>/<version>` — core group omits the group prefix. Use `kubectl api-resources` to find the right apiVersion for any kind.
