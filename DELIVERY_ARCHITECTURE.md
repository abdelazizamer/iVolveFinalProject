# Delivery Architecture and Safe Cutover

## Target flow

```text
Application source push to main
        |
        v
GitHub Actions CI (GitHub-hosted runner)
  build all 3 images -> Trivy scan -> push immutable SHA tags to ECR
        |
        v
Commit image tags to k8s/workloads.yaml
        |
        v
Argo CD watches the repository and syncs the private EKS cluster
```

GitHub Actions no longer talks to the Kubernetes API. It assumes the existing AWS OIDC role only to push images to ECR. Argo CD performs deployment from inside EKS. The app Services stay `ClusterIP`, and the EKS API stays private.

## What is temporary

The Jenkins EC2 remains declared in Terraform only as a temporary in-VPC bootstrap host. This is necessary for the private EKS endpoint and the user's decision to preserve the MySQL database while moving it from ephemeral storage to EBS. Jenkins CI code and the old direct-deploy workflow have been removed. Do not remove the EC2, its EKS access, or its security-group route before the migration and Argo CD checks below succeed. After that, remove the remaining `module.jenkins` resources in Terraform and review the destroy plan before applying it.

There is no Ansible configuration in this repository, so there are no Ansible files to remove.

## CI behavior

- `.github/workflows/ci.yml` runs on source/service changes to `main` or by manual dispatch.
- Three GitHub-hosted jobs build `frontend`, `auth-service`, and `roadmap-service` images, scan each image with Trivy, and push commit-SHA tags to the existing immutable ECR repositories.
- The final job commits those image tags to `k8s/workloads.yaml`. Kubernetes manifest-only commits do not match the CI path filter, so the bot commit does not start a second image build.
- The existing GitHub repository variable `AWS_ROLE_ARN` can keep its current ARN: Terraform moves the existing role in state while retaining its AWS role name. The role's permissions change from EKS access to ECR push only.
- The workflow does not read the old MySQL GitHub secrets. Keep the already-created Kubernetes Secret `app-secrets` in the cluster; never add its values to Git.

## Safe cutover sequence

### 1. Review the transitional Terraform plan

The repository is public, and the EC2 runner is no longer needed because the new CI uses `ubuntu-latest`. Before granting the EC2 role temporary cluster-admin access, stop its runner service and remove the runner from GitHub while keeping the EC2 itself available for SSH/SSM:

```bash
cd ~/actions-runner
sudo ./svc.sh stop
sudo ./svc.sh uninstall
```

Then open **GitHub → Settings → Actions → Runners** and remove the offline `ip-10-20-1-134` runner.

From `terraform/environments/dev` in PowerShell:

```powershell
$env:AWS_PROFILE = "root-dev"
terraform plan
```

Expected changes include the GitHub CI role policy change, temporary bootstrap access for the existing EC2, and EKS Pod Identity/EBS CSI resources. The plan must **not** destroy or replace `module.jenkins.aws_instance.jenkins`. If it does, stop and review the plan. Do not run `terraform apply` until the plan is reviewed and explicitly approved.

After the approved transitional infrastructure is applied, the EC2 instance role can describe the cluster and temporarily has cluster-admin access. Argo CD installation creates cluster-scoped RBAC/CRDs, which a namespace-scoped role cannot install. Its security group can reach the private EKS API. Remove this temporary cluster-admin association along with the EC2 at final retirement. The EBS CSI add-on and Pod Identity agent must be active before migration.

### 2. Run CI and confirm images

Push the reviewed repository changes to `main`. In GitHub, open **Actions → Build, scan, and publish images** and wait for all three matrix jobs and the manifest-update job to succeed. Confirm the resulting commit changes only `k8s/workloads.yaml` and its image tags are the full 40-character commit SHA.

### 3. Migrate MySQL from the in-VPC host

Connect to the existing EC2, then run:

```bash
cd /tmp
git clone https://github.com/abdelazizamer/iVolveFinalProject.git
cd iVolveFinalProject
aws eks update-kubeconfig --region us-east-1 --name ivolve-devops-eks
kubectl get nodes
kubectl get secret app-secrets -n default
bash scripts/migrate-mysql-stateful.sh
```

The script backs up `ivolve`, creates the EBS-backed StatefulSet, restores the database, compares the source and restored `users` row counts, and then switches the `mysql` Service to the StatefulSet. It keeps the old MySQL Deployment for rollback. The command must finish successfully before continuing. Never delete the old MySQL Deployment or its data until the EBS-backed database has been verified.

Verify the service is routed to the persistent database:

```bash
kubectl get service mysql -n default -o jsonpath='{.spec.selector.app}{"\n"}'
kubectl get pvc -n default
kubectl rollout status statefulset/mysql -n default --timeout=10m
```

The selector should print `mysql-stateful`, and the PVC should be `Bound`.

### 4. Install Argo CD and start GitOps sync

Still from the in-VPC EC2 and the cloned project directory:

```bash
bash scripts/bootstrap-argocd.sh
kubectl get applications.argoproj.io ivolve-devops -n argocd
kubectl get applications.argoproj.io ivolve-devops -n argocd -o wide
kubectl get deployments,pods,services -n default
```

The bootstrap script installs the upstream Argo CD `v3.6.1` manifests and applies `argocd/application.yaml`. The Application watches `main/k8s`, enables automated sync, pruning, and self-healing. It deliberately refuses to continue if the Kubernetes secret or the migrated MySQL StatefulSet is missing. The Argo CD UI is not exposed publicly.

Confirm the Application becomes `Synced` and `Healthy`, then check that Auth, Roadmap, Frontend, and MySQL rollouts are ready. If sync fails, inspect `kubectl describe application ivolve-devops -n argocd` and Argo CD controller/repo-server logs before retiring the EC2.

### 5. Retire Jenkins EC2 after verification

Once Argo CD is healthy and the application remains ready after a new CI image update, remove the temporary bootstrap permissions, VPC ingress rule, Jenkins EC2 module and related variables/outputs from Terraform. Review the resulting plan carefully. It should show the intended EC2/role/security-group/key destruction and must preserve EKS, ECR, network, EBS volume, and MySQL data. Apply only after reviewing and explicitly approving that exact destroy plan.

The runner is removed at the start of the cutover above; the EC2 remains only for private-cluster administration until final retirement.

## Operational notes

- ECR repositories use immutable tags. CI reuses an existing image tag if a workflow is rerun for the same Git SHA.
- `k8s/workloads.yaml` contains the AWS account ID and an already-published image tag as initial values. The CI update script replaces all three tags on each source build.
- The cluster endpoint and all app Services remain private/internal. Use the existing in-VPC host for initial bootstrap; normal deploys are then reconciled by Argo CD inside EKS.
- Argo CD install manifest is pinned to the upstream `v3.6.1` release: https://github.com/argoproj/argo-cd/releases/tag/v3.6.1.
