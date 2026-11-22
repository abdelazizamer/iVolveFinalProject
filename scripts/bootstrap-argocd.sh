#!/usr/bin/env bash
set -euo pipefail

cluster_name="ivolve-devops-eks"
region="us-east-1"
argocd_version="v3.6.1"

aws eks update-kubeconfig --region "$region" --name "$cluster_name"

kubectl get secret app-secrets --namespace default >/dev/null || {
  echo "Required Secret app-secrets is missing. Create it without committing its values, then retry." >&2
  exit 1
}

kubectl get statefulset mysql --namespace default >/dev/null || {
  echo "MySQL StatefulSet is not present. Migrate the existing MySQL data to EBS before Argo CD sync." >&2
  exit 1
}

kubectl rollout status statefulset/mysql --namespace default --timeout=10m

mysql_selector="$(kubectl get service mysql --namespace default -o jsonpath='{.spec.selector.app}')"
if [[ "$mysql_selector" != "mysql-stateful" ]]; then
  echo "Service/mysql must route to the verified EBS-backed StatefulSet; found selector: $mysql_selector" >&2
  exit 1
fi

# The EBS-backed StatefulSet is serving traffic; the old ephemeral Deployment is no longer needed.
kubectl scale deployment/mysql --namespace default --replicas=0 || true

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply --namespace argocd --server-side --force-conflicts \
  --filename "https://raw.githubusercontent.com/argoproj/argo-cd/${argocd_version}/manifests/install.yaml"

# This project uses one Application, has no notification routes, and has no Dex/OIDC login.
# Leave optional controllers disabled to fit the current two-node t3.small pod capacity.
kubectl scale deployment/argocd-applicationset-controller \
  deployment/argocd-notifications-controller deployment/argocd-dex-server \
  --namespace argocd --replicas=0

kubectl rollout status deployment/argocd-server --namespace argocd --timeout=10m
kubectl apply --filename argocd/application.yaml

echo "Argo CD is installed and the ivolve-devops Application was submitted."
echo "Check with: kubectl get applications.argoproj.io -n argocd ivolve-devops"
