#!/usr/bin/env bash
set -euo pipefail

# Creates the local k3d cluster with an attached image registry.
# Everything after this runs entirely offline except the one Gemini API
# call added in the Innovation hour.
echo "Creating k3d cluster 'sustain-workshop' with local registry..."
# Port 5500, not 5000: on macOS, ControlCenter's AirPlay Receiver binds
# 0.0.0.0:5000 by default, which makes cluster creation fail with
# "address already in use" on most attendee laptops.
k3d cluster create sustain-workshop --registry-create sustain-registry:0.0.0.0:5500

echo "Waiting for node to be ready..."
kubectl wait --for=condition=Ready node --all --timeout=90s

kubectl get nodes
echo "Cluster is ready."
