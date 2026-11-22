#!/usr/bin/env bash
set -euo pipefail

source_namespace="default"
target_namespace="ivolve"
secret_name="app-secrets"

command -v kubectl >/dev/null || { echo "kubectl is required" >&2; exit 1; }
command -v jq >/dev/null || { echo "jq is required to copy the Secret without printing its values" >&2; exit 1; }

kubectl get secret "$secret_name" --namespace "$source_namespace" >/dev/null
kubectl create namespace "$target_namespace" --dry-run=client -o yaml | kubectl apply -f -

# Copy the existing secret as JSON through a pipe. Secret values are never printed
# or passed as command-line arguments, and the source Secret remains in default
# for MySQL while the application workloads transition to the ivolve namespace.
kubectl get secret "$secret_name" --namespace "$source_namespace" --output json \
  | jq --arg namespace "$target_namespace" '
      del(.metadata.annotations,
          .metadata.creationTimestamp,
          .metadata.managedFields,
          .metadata.resourceVersion,
          .metadata.uid,
          .metadata.ownerReferences,
          .metadata.finalizers)
      | .metadata.namespace = $namespace
    ' \
  | kubectl apply --filename -

for key in MYSQL_PASSWORD MYSQL_ROOT_PASSWORD SESSION_SECRET; do
  kubectl get secret "$secret_name" --namespace "$target_namespace" \
    --output "jsonpath={.data.${key}}" | grep -q . || {
      echo "Copied Secret is missing required key: $key" >&2
      exit 1
    }
done

kubectl apply --filename argocd/application.yaml
echo "Namespace and secret are ready. Argo CD will reconcile the application workloads into ${target_namespace}; MySQL and its existing PVC remain in ${source_namespace}."
