#!/usr/bin/env bash
set -euo pipefail

# Demonstrates self-healing (Deployment replaces a killed pod) and the
# PodDisruptionBudget (drain can't take down both replicas at once) added
# in the Resilience hour. Run against the ngo-a namespace as the example;
# the same behavior applies to ngo-b and shared.

NS="ngo-a"

echo "=== Part 1: kill a pod, prove zero-downtime self-healing ==="
kubectl get pods -n "$NS" -l app=resource-api

echo "Starting a background health-check loop against the Service..."
kubectl port-forward -n "$NS" svc/resource-api 18080:80 >/tmp/chaos-pf.log 2>&1 &
PF_PID=$!
trap 'kill $PF_PID 2>/dev/null || true' EXIT
sleep 2

( for i in $(seq 1 20); do
    curl -s -o /dev/null -w "%{http_code} " localhost:18080/health || printf "ERR "
    sleep 0.5
  done
  echo
) &
CURL_PID=$!

sleep 1
VICTIM=$(kubectl get pod -n "$NS" -l app=resource-api -o jsonpath='{.items[0].metadata.name}')
echo "Deleting pod $VICTIM ..."
kubectl delete pod -n "$NS" "$VICTIM" --wait=false

wait "$CURL_PID"
echo "^ every code above should read 200 — the Service kept routing to the"
echo "  surviving replica while the deleted one was replaced."

kubectl wait -n "$NS" --for=condition=Ready pod -l app=resource-api --timeout=60s
kubectl get pods -n "$NS" -l app=resource-api

echo
echo "=== Part 2: PodDisruptionBudget blocks a full-namespace drain ==="
echo "PDB for $NS:"
kubectl get pdb -n "$NS"

NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
echo "Draining the (only) node '$NODE' for 15s — this is expected to fail."
echo "This is intentional: it proves the PDB is blocking a would-be total"
echo "outage, NOT that draining actually works here. A single-node k3d"
echo "cluster has nowhere else to reschedule evicted pods, so a real drain"
echo "can never fully succeed — see KNOWLEDGE.md for why this doesn't"
echo "simulate real node failure."
set +e
kubectl drain "$NODE" --ignore-daemonsets --delete-emptydir-data --timeout=15s
set -e

echo "Uncordoning $NODE and letting the Deployment reconcile back to 2/2 ..."
kubectl uncordon "$NODE"
kubectl rollout status deployment/resource-api -n "$NS" --timeout=60s
kubectl get pods -n "$NS" -l app=resource-api

echo
echo "Chaos drill complete."
