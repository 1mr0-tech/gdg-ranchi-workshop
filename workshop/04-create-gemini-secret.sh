#!/usr/bin/env bash
set -euo pipefail

# Creates (or updates) the gemini-api-key Secret in the shared namespace
# directly from the local key.txt file. key.txt is git-ignored and its
# contents are never echoed, logged, or written anywhere by this script —
# it goes straight from disk into the Secret via kubectl.
KEY_FILE="key.txt"

if [ ! -f "$KEY_FILE" ]; then
  echo "ERROR: $KEY_FILE not found in the current directory." >&2
  echo "Create it with your Gemini API key (one line, no quotes) before running this script." >&2
  exit 1
fi

if ! kubectl get namespace shared >/dev/null 2>&1; then
  echo "ERROR: namespace 'shared' does not exist yet." >&2
  echo "Run ./scripts/02-deploy.sh first so the namespace picks up its real labels." >&2
  exit 1
fi

kubectl create secret generic gemini-api-key -n shared \
  --from-file=GEMINI_API_KEY="$KEY_FILE" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Secret 'gemini-api-key' created/updated in namespace 'shared'."
echo "Verifying existence (not decoding the value):"
kubectl get secret gemini-api-key -n shared
