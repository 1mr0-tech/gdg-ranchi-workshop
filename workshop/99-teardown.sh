#!/usr/bin/env bash
set -euo pipefail

echo "Deleting k3d cluster 'sustain-workshop'..."
k3d cluster delete sustain-workshop
echo "Done. Environment fully reset."
