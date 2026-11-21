#!/usr/bin/env bash
set -euo pipefail

namespace="default"
service="mysql"
statefulset="mysql"
backup_file="$(mktemp "${RUNNER_TEMP:-/tmp}/mysql-migration.XXXXXX.sql")"
chmod 600 "$backup_file"
apps_paused=false
service_switched=false

rollback_on_failure() {
  status=$?
  if (( status != 0 )); then
    echo "MySQL migration failed; attempting to restore the old database route."
    if [[ "$service_switched" == true ]]; then
      kubectl patch service "$service" --namespace "$namespace" \
        --type=merge -p '{"spec":{"selector":{"app":"mysql"}}}' || true
    fi
    if [[ "$apps_paused" == true ]]; then
      kubectl scale deployment/auth-service deployment/frontend \
        --namespace "$namespace" --replicas=1 || true
    fi
  fi
  rm -f "$backup_file"
  return "$status"
}
trap rollback_on_failure EXIT

current_selector="$(kubectl get service "$service" --namespace "$namespace" \
  -o jsonpath='{.spec.selector.app}')"
if [[ "$current_selector" == "mysql-stateful" ]]; then
  echo "The StatefulSet database is already serving traffic; no migration is needed."
  exit 0
fi
if [[ "$current_selector" != "mysql" ]]; then
  echo "Unexpected selector on service/$service: $current_selector" >&2
  exit 1
fi
kubectl get deployment/mysql --namespace "$namespace" >/dev/null

source_users="$(kubectl exec --namespace "$namespace" deployment/mysql -- sh -c \
  'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql --user=root --batch --skip-column-names --execute="SELECT COUNT(*) FROM ivolve.users"')"
echo "Backing up the current MySQL database ($source_users user rows)."
kubectl exec --namespace "$namespace" deployment/mysql -- sh -c \
  'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysqldump --user=root --single-transaction --routines --triggers --databases ivolve' \
  > "$backup_file"
test -s "$backup_file"

kubectl apply -f k8s/storage.yaml
kubectl rollout status "statefulset/$statefulset" --namespace "$namespace" --timeout=10m
echo "Restoring the database into the persistent volume."
kubectl exec --namespace "$namespace" --stdin "${statefulset}-0" -- sh -c \
  'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql --user=root' < "$backup_file"

target_users="$(kubectl exec --namespace "$namespace" "${statefulset}-0" -- sh -c \
  'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql --user=root --batch --skip-column-names --execute="SELECT COUNT(*) FROM ivolve.users"')"
if [[ "$source_users" != "$target_users" ]]; then
  echo "Row count mismatch after restore (source=$source_users target=$target_users)." >&2
  exit 1
fi

echo "Pausing frontend and auth while switching the MySQL service."
kubectl scale deployment/auth-service deployment/frontend --namespace "$namespace" --replicas=0
apps_paused=true
kubectl patch service "$service" --namespace "$namespace" --type=merge \
  -p '{"spec":{"selector":{"app":"mysql-stateful"}}}'
service_switched=true
kubectl scale deployment/auth-service deployment/frontend --namespace "$namespace" --replicas=1
apps_paused=false
service_switched=false
echo "Database copied and service switched. The old MySQL Deployment is retained for rollback."
