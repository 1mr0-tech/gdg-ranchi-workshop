#!/usr/bin/env bash
set -euo pipefail

# Must match the registry port k3d created in 00-setup-cluster.sh.
REGISTRY="localhost:5500"

echo "Building resource-api image..."
docker build -t ${REGISTRY}/resource-api:latest ./app/resource-api
docker push ${REGISTRY}/resource-api:latest

# ai-gateway only exists from hour3 onward — build it if present so this
# same script keeps working unchanged across every branch.
if [ -d "./app/ai-gateway" ]; then
  echo "Building ai-gateway image..."
  docker build -t ${REGISTRY}/ai-gateway:latest ./app/ai-gateway
  docker push ${REGISTRY}/ai-gateway:latest
fi

echo "Images pushed to local registry."
