# Commands Reference

Every command a facilitator or attendee will type across the whole
workshop, grouped by hour. The **scripts stay as scripts** — you still run
`./scripts/00-setup-cluster.sh`, `01-build-and-push.sh`,
`03-chaos-drill.sh`, `04-create-gemini-secret.sh`, and `99-teardown.sh` as
single commands, exactly as before.

Every **Kubernetes manifest**, though, is written out here as something
you open in an editor and type yourself, live, rather than something a
script silently applies for you. The idea: reading a YAML block on a slide
and typing it into `nano` builds real muscle memory for the shape of a
Role, a NetworkPolicy, a Deployment — copy-pasting a pre-written file
doesn't.

**Editor convention used throughout:** `nano <file>` to open/create the
file, type the block shown, then **Ctrl+O, Enter** to save and **Ctrl+X**
to exit. (If you prefer `vi`/`vim`, swap the `nano` command for
`vi <file>`, use `i` to enter insert mode, `Esc` then `:wq` to save and
quit — the YAML content is identical either way.)

Once a manifest is saved, apply it immediately with `kubectl apply -f
<path>` so you get instant feedback (object created / error) before
moving to the next file. `scripts/02-deploy.sh` still exists and still
works — `kubectl apply -R -f ./k8s` is idempotent, so running it after
you've hand-typed everything is a safe way to confirm nothing was missed,
not a replacement for typing it.

---

## Hour 0 — Setup (branch `main`)

```bash
# Creates the local k3d cluster with an attached image registry on port
# 5500 (not 5000 — macOS ControlCenter's AirPlay Receiver squats on 5000).
./scripts/00-setup-cluster.sh

# Builds the resource-api image and pushes it to the local registry; also
# builds ai-gateway if that directory exists (branch hour3+).
./scripts/01-build-and-push.sh
```

### Type the namespace

```bash
nano k8s/namespace.yaml
```

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: workshop
```

```bash
kubectl apply -f k8s/namespace.yaml
```

### Type the Deployment

```bash
nano k8s/deployment.yaml
```

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: resource-api
  namespace: workshop
spec:
  replicas: 1
  selector:
    matchLabels:
      app: resource-api
  template:
    metadata:
      labels:
        app: resource-api
    spec:
      containers:
        - name: resource-api
          # In-cluster kubelet pulls resolve via the containerd mirror k3d
          # configures for the registry's own container name+port
          # (sustain-registry:5500), NOT "localhost:5500" — localhost inside
          # a node's network namespace has nothing listening on that port.
          image: sustain-registry:5500/resource-api:latest
          ports:
            - containerPort: 8080
          env:
            - name: NGO_ID
              value: "demo"
```

```bash
kubectl apply -f k8s/deployment.yaml
```

### Type the Service

```bash
nano k8s/service.yaml
```

```yaml
apiVersion: v1
kind: Service
metadata:
  name: resource-api
  namespace: workshop
spec:
  selector:
    app: resource-api
  ports:
    - port: 80
      targetPort: 8080
```

```bash
kubectl apply -f k8s/service.yaml
```

### Verify

```bash
# Forwards the workshop namespace's Service to your machine so you can
# curl it without exposing anything outside the cluster.
kubectl port-forward -n workshop svc/resource-api 8080:80

# Confirms the app is actually serving traffic and reports its identity.
curl localhost:8080/health

# Lists the two seeded resources.
curl localhost:8080/resources

# Adds a new resource — proves POST/write path works, not just GET.
curl -X POST localhost:8080/resources -H 'Content-Type: application/json' -d '{"name":"Test item"}'
```

---

## Moving between hours

```bash
# Switches to the next checkpoint branch — each hour changes the k8s/
# manifest layout, so the previous hour's namespace(s) must be cleared
# first (see the per-hour commands below for exactly which to delete).
git checkout hour1-cooperation   # or hour2-resilience / hour3-innovation
```

---

## Hour 1 — Cooperation (branch `hour1-cooperation`)

```bash
# Hour 0 used a single "workshop" namespace; Hour 1 replaces it with
# ngo-a / ngo-b / shared, so remove the old one before typing anything new.
kubectl delete namespace workshop --ignore-not-found

./scripts/01-build-and-push.sh
```

### Namespaces

```bash
nano k8s/ngo-a/namespace.yaml
```

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: ngo-a
  labels:
    ngo: a
```

```bash
kubectl apply -f k8s/ngo-a/namespace.yaml
nano k8s/ngo-b/namespace.yaml
```

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: ngo-b
  labels:
    ngo: b
```

```bash
kubectl apply -f k8s/ngo-b/namespace.yaml
nano k8s/shared/namespace.yaml
```

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: shared
  labels:
    tier: shared
```

```bash
kubectl apply -f k8s/shared/namespace.yaml
```

### Deployments (same resource-api image, different NGO_ID per tenant)

```bash
nano k8s/ngo-a/deployment.yaml
```

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: resource-api
  namespace: ngo-a
spec:
  replicas: 1
  selector:
    matchLabels:
      app: resource-api
  template:
    metadata:
      labels:
        app: resource-api
    spec:
      containers:
        - name: resource-api
          image: sustain-registry:5500/resource-api:latest
          ports:
            - containerPort: 8080
          env:
            - name: NGO_ID
              value: "ngo-a"
```

```bash
kubectl apply -f k8s/ngo-a/deployment.yaml
nano k8s/ngo-b/deployment.yaml
```

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: resource-api
  namespace: ngo-b
spec:
  replicas: 1
  selector:
    matchLabels:
      app: resource-api
  template:
    metadata:
      labels:
        app: resource-api
    spec:
      containers:
        - name: resource-api
          image: sustain-registry:5500/resource-api:latest
          ports:
            - containerPort: 8080
          env:
            - name: NGO_ID
              value: "ngo-b"
```

```bash
kubectl apply -f k8s/ngo-b/deployment.yaml
nano k8s/shared/deployment.yaml
```

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: resource-api
  namespace: shared
spec:
  replicas: 1
  selector:
    matchLabels:
      app: resource-api
  template:
    metadata:
      labels:
        app: resource-api
    spec:
      containers:
        - name: resource-api
          image: sustain-registry:5500/resource-api:latest
          ports:
            - containerPort: 8080
          env:
            - name: NGO_ID
              value: "shared"
```

```bash
kubectl apply -f k8s/shared/deployment.yaml
```

### Services

```bash
nano k8s/ngo-a/service.yaml
```

```yaml
apiVersion: v1
kind: Service
metadata:
  name: resource-api
  namespace: ngo-a
spec:
  selector:
    app: resource-api
  ports:
    - port: 80
      targetPort: 8080
```

```bash
kubectl apply -f k8s/ngo-a/service.yaml
nano k8s/ngo-b/service.yaml
```

```yaml
apiVersion: v1
kind: Service
metadata:
  name: resource-api
  namespace: ngo-b
spec:
  selector:
    app: resource-api
  ports:
    - port: 80
      targetPort: 8080
```

```bash
kubectl apply -f k8s/ngo-b/service.yaml
nano k8s/shared/service.yaml
```

```yaml
apiVersion: v1
kind: Service
metadata:
  name: resource-api
  namespace: shared
spec:
  selector:
    app: resource-api
  ports:
    - port: 80
      targetPort: 8080
```

```bash
kubectl apply -f k8s/shared/service.yaml
```

### RBAC — a ServiceAccount + Role + RoleBinding per tenant

```bash
nano k8s/ngo-a/rbac.yaml
```

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ngo-a-operator
  namespace: ngo-a
---
# Role is namespace-scoped by definition — this grant physically cannot
# reach ngo-b or shared, unlike a ClusterRole which would.
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: ngo-a-operator
  namespace: ngo-a
rules:
  - apiGroups: ["", "apps"]
    resources: ["pods", "services", "deployments"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ngo-a-operator
  namespace: ngo-a
subjects:
  - kind: ServiceAccount
    name: ngo-a-operator
    namespace: ngo-a
roleRef:
  kind: Role
  name: ngo-a-operator
  apiGroup: rbac.authorization.k8s.io
```

```bash
kubectl apply -f k8s/ngo-a/rbac.yaml
nano k8s/ngo-b/rbac.yaml
```

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ngo-b-operator
  namespace: ngo-b
---
# Role is namespace-scoped by definition — this grant physically cannot
# reach ngo-a or shared, unlike a ClusterRole would.
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: ngo-b-operator
  namespace: ngo-b
rules:
  - apiGroups: ["", "apps"]
    resources: ["pods", "services", "deployments"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ngo-b-operator
  namespace: ngo-b
subjects:
  - kind: ServiceAccount
    name: ngo-b-operator
    namespace: ngo-b
roleRef:
  kind: Role
  name: ngo-b-operator
  apiGroup: rbac.authorization.k8s.io
```

```bash
kubectl apply -f k8s/ngo-b/rbac.yaml
```

### NetworkPolicy — tenant isolation + the shared cooperation channel

```bash
nano k8s/ngo-a/networkpolicy.yaml
```

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: same-namespace-only
  namespace: ngo-a
spec:
  podSelector: {}
  policyTypes:
    - Ingress
  ingress:
    # A peer with only a podSelector (no namespaceSelector) matches pods in
    # THIS namespace only — this is what makes ngo-b unreachable from ngo-a
    # and vice versa, while pods within ngo-a can still talk to each other.
    - from:
        - podSelector: {}
```

```bash
kubectl apply -f k8s/ngo-a/networkpolicy.yaml
nano k8s/ngo-b/networkpolicy.yaml
```

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: same-namespace-only
  namespace: ngo-b
spec:
  podSelector: {}
  policyTypes:
    - Ingress
  ingress:
    # A peer with only a podSelector (no namespaceSelector) matches pods in
    # THIS namespace only — this is what makes ngo-a unreachable from ngo-b
    # and vice versa, while pods within ngo-b can still talk to each other.
    - from:
        - podSelector: {}
```

```bash
kubectl apply -f k8s/ngo-b/networkpolicy.yaml
nano k8s/shared/networkpolicy.yaml
```

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-ngo-tenants-only
  namespace: shared
spec:
  podSelector: {}
  policyTypes:
    - Ingress
  ingress:
    # Both tenants are allowed to reach the shared coordinator, but nothing
    # else is (no other namespace, no outside traffic) — this is the
    # "cooperate without merging" boundary the lab demonstrates.
    - from:
        - namespaceSelector:
            matchLabels:
              ngo: a
        - namespaceSelector:
            matchLabels:
              ngo: b
        - podSelector: {}
```

```bash
kubectl apply -f k8s/shared/networkpolicy.yaml
```

### Verify Hour 1

```bash
kubectl wait -n ngo-a --for=condition=Ready pod -l app=resource-api --timeout=60s
kubectl wait -n ngo-b --for=condition=Ready pod -l app=resource-api --timeout=60s
kubectl wait -n shared --for=condition=Ready pod -l app=resource-api --timeout=60s

# RBAC check: ngo-a's own service account can see its own namespace...
kubectl auth can-i list pods -n ngo-a --as=system:serviceaccount:ngo-a:ngo-a-operator
# ...but not ngo-b's.
kubectl auth can-i list pods -n ngo-b --as=system:serviceaccount:ngo-a:ngo-a-operator
# ...and not resources the Role never granted, like Secrets.
kubectl auth can-i list secrets -n ngo-a --as=system:serviceaccount:ngo-a:ngo-a-operator

# NetworkPolicy check: grab pod names/IPs to test tenant isolation directly.
A_POD=$(kubectl get pod -n ngo-a -l app=resource-api -o jsonpath='{.items[0].metadata.name}')
B_IP=$(kubectl get pod -n ngo-b -l app=resource-api -o jsonpath='{.items[0].status.podIP}')

# Cross-tenant call — must be BLOCKED by the NetworkPolicy, not just slow.
kubectl exec -n ngo-a "$A_POD" -- wget -qO- --timeout=5 http://$B_IP:8080/health

# Call to the shared coordinator — must be ALLOWED (cooperation without merging).
kubectl exec -n ngo-a "$A_POD" -- wget -qO- --timeout=5 http://resource-api.shared.svc.cluster.local/health

# Reset for Hour 2 — no separate namespaces to keep, Hour 2 reuses these.
kubectl delete namespace ngo-a ngo-b shared
```

---

## Hour 2 — Resilience (branch `hour2-resilience`)

```bash
git checkout hour2-resilience
./scripts/01-build-and-push.sh
```

Hour 2 doesn't add new namespaces — it edits the same `deployment.yaml`
files from Hour 1 (adding `replicas`, `resources`, and probes) and adds a
new `pdb.yaml` per namespace. If you deleted `ngo-a`/`ngo-b`/`shared` at
the end of Hour 1, re-type the namespace/service/rbac/networkpolicy files
from the Hour 1 section above first, then continue here.

### Updated Deployment — replicas, resource limits, probes

```bash
nano k8s/ngo-a/deployment.yaml
```

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: resource-api
  namespace: ngo-a
spec:
  # 2 replicas so a single pod loss (crash, delete, rollout) doesn't drop
  # the service — this is what the chaos drill exercises.
  replicas: 2
  selector:
    matchLabels:
      app: resource-api
  template:
    metadata:
      labels:
        app: resource-api
    spec:
      containers:
        - name: resource-api
          image: sustain-registry:5500/resource-api:latest
          ports:
            - containerPort: 8080
          env:
            - name: NGO_ID
              value: "ngo-a"
          # Requests/limits so the scheduler can bin-pack correctly and one
          # runaway pod can't starve its neighbors of node CPU/memory.
          resources:
            requests:
              cpu: 50m
              memory: 64Mi
            limits:
              cpu: 200m
              memory: 128Mi
          # Readiness gates traffic: the Service stops routing to this pod
          # the moment /health fails, before users notice.
          readinessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 2
            periodSeconds: 5
          # Liveness restarts a pod that's wedged (process up, but stuck) —
          # distinct from readiness, which only stops traffic.
          livenessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 5
            periodSeconds: 10
```

```bash
kubectl apply -f k8s/ngo-a/deployment.yaml
nano k8s/ngo-b/deployment.yaml
```

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: resource-api
  namespace: ngo-b
spec:
  # 2 replicas so a single pod loss (crash, delete, rollout) doesn't drop
  # the service — this is what the chaos drill exercises.
  replicas: 2
  selector:
    matchLabels:
      app: resource-api
  template:
    metadata:
      labels:
        app: resource-api
    spec:
      containers:
        - name: resource-api
          image: sustain-registry:5500/resource-api:latest
          ports:
            - containerPort: 8080
          env:
            - name: NGO_ID
              value: "ngo-b"
          # Requests/limits so the scheduler can bin-pack correctly and one
          # runaway pod can't starve its neighbors of node CPU/memory.
          resources:
            requests:
              cpu: 50m
              memory: 64Mi
            limits:
              cpu: 200m
              memory: 128Mi
          # Readiness gates traffic: the Service stops routing to this pod
          # the moment /health fails, before users notice.
          readinessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 2
            periodSeconds: 5
          # Liveness restarts a pod that's wedged (process up, but stuck) —
          # distinct from readiness, which only stops traffic.
          livenessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 5
            periodSeconds: 10
```

```bash
kubectl apply -f k8s/ngo-b/deployment.yaml
nano k8s/shared/deployment.yaml
```

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: resource-api
  namespace: shared
spec:
  # 2 replicas so a single pod loss (crash, delete, rollout) doesn't drop
  # the service — this is what the chaos drill exercises.
  replicas: 2
  selector:
    matchLabels:
      app: resource-api
  template:
    metadata:
      labels:
        app: resource-api
    spec:
      containers:
        - name: resource-api
          image: sustain-registry:5500/resource-api:latest
          ports:
            - containerPort: 8080
          env:
            - name: NGO_ID
              value: "shared"
          # Requests/limits so the scheduler can bin-pack correctly and one
          # runaway pod can't starve its neighbors of node CPU/memory.
          resources:
            requests:
              cpu: 50m
              memory: 64Mi
            limits:
              cpu: 200m
              memory: 128Mi
          # Readiness gates traffic: the Service stops routing to this pod
          # the moment /health fails, before users notice.
          readinessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 2
            periodSeconds: 5
          # Liveness restarts a pod that's wedged (process up, but stuck) —
          # distinct from readiness, which only stops traffic.
          livenessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 5
            periodSeconds: 10
```

```bash
kubectl apply -f k8s/shared/deployment.yaml
```

### PodDisruptionBudgets

```bash
nano k8s/ngo-a/pdb.yaml
```

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: resource-api
  namespace: ngo-a
spec:
  # With replicas: 2, this blocks a *voluntary* disruption (node drain,
  # descheduler) from ever taking both pods down at once — it does not
  # protect against involuntary loss (pod crash, node hard-failure).
  minAvailable: 1
  selector:
    matchLabels:
      app: resource-api
```

```bash
kubectl apply -f k8s/ngo-a/pdb.yaml
nano k8s/ngo-b/pdb.yaml
```

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: resource-api
  namespace: ngo-b
spec:
  # With replicas: 2, this blocks a *voluntary* disruption (node drain,
  # descheduler) from ever taking both pods down at once — it does not
  # protect against involuntary loss (pod crash, node hard-failure).
  minAvailable: 1
  selector:
    matchLabels:
      app: resource-api
```

```bash
kubectl apply -f k8s/ngo-b/pdb.yaml
nano k8s/shared/pdb.yaml
```

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: resource-api
  namespace: shared
spec:
  # With replicas: 2, this blocks a *voluntary* disruption (node drain,
  # descheduler) from ever taking both pods down at once — it does not
  # protect against involuntary loss (pod crash, node hard-failure).
  minAvailable: 1
  selector:
    matchLabels:
      app: resource-api
```

```bash
kubectl apply -f k8s/shared/pdb.yaml
```

### Verify Hour 2

```bash
kubectl rollout status deployment/resource-api -n ngo-a --timeout=90s
kubectl rollout status deployment/resource-api -n ngo-b --timeout=90s
kubectl rollout status deployment/resource-api -n shared --timeout=90s

# Confirms probes and resource requests/limits actually landed on the
# live object, not just in the YAML source.
kubectl get deployment resource-api -n ngo-a -o yaml | grep -A4 readinessProbe
kubectl get deployment resource-api -n ngo-a -o yaml | grep -A4 resources:

# Runs the full chaos drill: kills a pod to prove zero-downtime
# self-healing, then drains the node to prove the PodDisruptionBudget
# blocks a full-namespace outage.
./scripts/03-chaos-drill.sh

# Manual PDB inspection, if you want to see the budget without the script.
kubectl get pdb -n ngo-a
```

---

## Hour 3 — Innovation (branch `hour3-innovation`)

```bash
git checkout hour3-innovation
./scripts/01-build-and-push.sh
```

Hour 3 keeps every Hour 1/2 manifest as-is and adds new files: two new
NetworkPolicies in `ngo-a`/`ngo-b` (egress lockdown), and three new files
plus two new NetworkPolicies in `shared` (the `ai-gateway` service).

### Zero-trust egress for the tenant namespaces

```bash
nano k8s/ngo-a/networkpolicy-egress.yaml
```

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: zero-trust-egress
  namespace: ngo-a
spec:
  # Default-deny-then-allow: once policyTypes includes Egress, ALL egress
  # from these pods is blocked except what's explicitly listed below. No
  # tenant pod gets direct internet access — /suggest must go through the
  # ai-gateway in the shared namespace, which is the only workload holding
  # the Gemini API key.
  podSelector: {}
  policyTypes:
    - Egress
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
    - to:
        - namespaceSelector:
            matchLabels:
              tier: shared
    - to:
        - podSelector: {}
```

```bash
kubectl apply -f k8s/ngo-a/networkpolicy-egress.yaml
nano k8s/ngo-b/networkpolicy-egress.yaml
```

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: zero-trust-egress
  namespace: ngo-b
spec:
  # Default-deny-then-allow: once policyTypes includes Egress, ALL egress
  # from these pods is blocked except what's explicitly listed below. No
  # tenant pod gets direct internet access — /suggest must go through the
  # ai-gateway in the shared namespace, which is the only workload holding
  # the Gemini API key.
  podSelector: {}
  policyTypes:
    - Egress
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
    - to:
        - namespaceSelector:
            matchLabels:
              tier: shared
    - to:
        - podSelector: {}
```

```bash
kubectl apply -f k8s/ngo-b/networkpolicy-egress.yaml
```

### The ai-gateway Deployment, Service, and PDB

```bash
nano k8s/shared/ai-gateway-deployment.yaml
```

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ai-gateway
  namespace: shared
spec:
  replicas: 2
  selector:
    matchLabels:
      app: ai-gateway
  template:
    metadata:
      labels:
        app: ai-gateway
    spec:
      containers:
        - name: ai-gateway
          image: sustain-registry:5500/ai-gateway:latest
          ports:
            - containerPort: 8080
          env:
            # Only this Deployment ever mounts this Secret — tenant
            # Deployments in ngo-a/ngo-b have no RBAC grant or manifest
            # reference to it at all. Created by
            # scripts/04-create-gemini-secret.sh, not committed to git.
            - name: GEMINI_API_KEY
              valueFrom:
                secretKeyRef:
                  name: gemini-api-key
                  key: GEMINI_API_KEY
          resources:
            requests:
              cpu: 50m
              memory: 64Mi
            limits:
              cpu: 200m
              memory: 128Mi
          readinessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 2
            periodSeconds: 5
          livenessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 5
            periodSeconds: 10
```

```bash
kubectl apply -f k8s/shared/ai-gateway-deployment.yaml
```

Expected right now: these pods sit in `CreateContainerConfigError` — the
Secret they reference doesn't exist yet. That's the intended "before"
state; keep going.

```bash
nano k8s/shared/ai-gateway-service.yaml
```

```yaml
apiVersion: v1
kind: Service
metadata:
  name: ai-gateway
  namespace: shared
spec:
  selector:
    app: ai-gateway
  ports:
    - port: 80
      targetPort: 8080
```

```bash
kubectl apply -f k8s/shared/ai-gateway-service.yaml
nano k8s/shared/ai-gateway-pdb.yaml
```

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: ai-gateway
  namespace: shared
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: ai-gateway
```

```bash
kubectl apply -f k8s/shared/ai-gateway-pdb.yaml
```

### Zero-trust egress inside the shared namespace

```bash
nano k8s/shared/networkpolicy-egress-resource-api.yaml
```

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: zero-trust-egress-resource-api
  namespace: shared
spec:
  # Even inside the "trusted" shared namespace, only ai-gateway gets
  # internet egress — the plain resource-api broker here gets none. Being
  # in a trusted namespace isn't a blanket grant; each workload gets only
  # what it specifically needs (least privilege), which is the same
  # principle RBAC enforces for identities.
  podSelector:
    matchLabels:
      app: resource-api
  policyTypes:
    - Egress
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
    - to:
        - podSelector: {}
```

```bash
kubectl apply -f k8s/shared/networkpolicy-egress-resource-api.yaml
nano k8s/shared/networkpolicy-egress-ai-gateway.yaml
```

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: zero-trust-egress-ai-gateway
  namespace: shared
spec:
  podSelector:
    matchLabels:
      app: ai-gateway
  policyTypes:
    - Egress
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
    # NetworkPolicy can only filter by IP/CIDR and port, not by hostname —
    # there is no way to express "only generativelanguage.googleapis.com"
    # here. This allows HTTPS to any address, which is real least-privilege
    # by PORT but not by DESTINATION. Locking this down further needs an
    # egress proxy or a CNI with FQDN-based policies (e.g. Cilium), which
    # is out of scope for this workshop — see KNOWLEDGE.md.
    - to:
        - ipBlock:
            cidr: 0.0.0.0/0
      ports:
        - protocol: TCP
          port: 443
```

```bash
kubectl apply -f k8s/shared/networkpolicy-egress-ai-gateway.yaml
```

### Create the Secret and run the real end-to-end test

```bash
# Reads key.txt (never committed — see .gitignore) straight into a
# Kubernetes Secret. The key is never echoed, logged, or written anywhere
# else by this script.
./scripts/04-create-gemini-secret.sh

# Confirms the Secret exists WITHOUT decoding its value.
kubectl get secret gemini-api-key -n shared

# ai-gateway pods self-heal once the Secret appears — no restart needed.
kubectl wait -n shared --for=condition=Ready pod -l app=ai-gateway --timeout=60s

# The real end-to-end test: call /suggest from INSIDE a tenant pod and get
# back a genuine Gemini response, proving the whole chain works.
A_POD=$(kubectl get pod -n ngo-a -l app=resource-api -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n ngo-a "$A_POD" -- wget -qO- --timeout=25 \
  --header='Content-Type: application/json' \
  --post-data='{"prompt":"In one short sentence, name one common household item an NGO resource-sharing platform might list for lending."}' \
  http://ai-gateway.shared.svc.cluster.local/suggest

# If that 502s, check the upstream error — Gemini's free-tier model names
# change over time and the error body usually names the replacement.
kubectl logs -n shared -l app=ai-gateway --tail=10

# Proves the key never reaches a tenant pod: no env var referencing it...
kubectl exec -n ngo-a "$A_POD" -- printenv | grep -i gemini

# ...and no RBAC grant lets ngo-a's identity even read the Secret's metadata.
kubectl auth can-i get secret/gemini-api-key -n shared --as=system:serviceaccount:ngo-a:ngo-a-operator

# Proves zero-trust egress: a tenant pod cannot reach the internet directly...
kubectl exec -n ngo-a "$A_POD" -- wget -qO- --timeout=8 https://generativelanguage.googleapis.com

# ...and neither can the plain broker pod inside the "trusted" shared
# namespace — only ai-gateway specifically is allowed outbound HTTPS.
S_POD=$(kubectl get pod -n shared -l app=resource-api -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n shared "$S_POD" -- wget -qO- --timeout=8 https://generativelanguage.googleapis.com
```

---

## Teardown (any hour)

```bash
# Deletes the entire k3d cluster, including any Secrets created in it.
# key.txt on local disk is untouched.
./scripts/99-teardown.sh
```
