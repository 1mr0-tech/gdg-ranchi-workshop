#!/usr/bin/env bash
set -euo pipefail

echo "Applying all manifests under k8s/ ..."
# Namespaces must exist before anything that lives in them, but
# `kubectl apply -R -f` applies files in alphabetical order — deployment.yaml
# sorts before namespace.yaml, so a first-time apply against a clean cluster
# fails with "namespaces ... not found". Apply every namespace.yaml first.
find ./k8s -name 'namespace.yaml' -exec kubectl apply -f {} \;
kubectl apply -R -f ./k8s

echo "Current pods in workshop-related namespaces:"
kubectl get pods --all-namespaces | grep -E "NAMESPACE|workshop|ngo-|shared" || true
