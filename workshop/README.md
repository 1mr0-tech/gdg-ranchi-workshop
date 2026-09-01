# Secure, Resilient & Cooperative Platforms — Workshop Repo

A 3-hour, fully local, free-to-run workshop combining the **Cooperation**,
**Resilience**, and **Innovation** pillars around one app: a small NGO
resource-sharing platform deployed on a local Kubernetes cluster (k3d).

## Prerequisites (install before the session)

- Docker Desktop (or Docker Engine)
- [k3d](https://k3d.io/) — local Kubernetes in Docker
- kubectl
- Node.js 20+ (only needed to run resource-api outside Docker)

Nothing here requires a Google Cloud billing account. The only external
network call in the whole workshop is the Gemini API request added in the
Innovation hour, and that uses the free tier — verify current limits before
the session since free-tier terms can change.

## Branch map

| Branch | Covers |
|---|---|
| `main` | Hour 0: base app + single-namespace deploy |
| `hour1-cooperation` | Multi-tenant namespaces, RBAC, NetworkPolicies, shared API |
| `hour2-resilience` | Probes, PodDisruptionBudgets, chaos drill script |
| `hour3-innovation` | AI gateway pod, Gemini integration, zero-trust egress policy |

## Hour 0 — Setup

```bash
./scripts/00-setup-cluster.sh
./scripts/01-build-and-push.sh
./scripts/02-deploy.sh
kubectl port-forward -n workshop svc/resource-api 8080:80
curl localhost:8080/health
```

## Moving to the next hour

```bash
git checkout hour1-cooperation
./scripts/01-build-and-push.sh
./scripts/02-deploy.sh
```

## Teardown

```bash
./scripts/99-teardown.sh
```
