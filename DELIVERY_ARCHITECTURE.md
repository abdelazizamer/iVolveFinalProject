# Delivery Architecture and Retirement Plan

## Current delivery flow

```text
Application source push to main
        |
        v
GitHub Actions CI (GitHub-hosted runner)
  build three images -> Trivy scan -> push immutable SHA tags to ECR
        |
        v
Commit image tags to k8s/workloads.yaml
        |
        v
Argo CD watches main/k8s and syncs the private EKS cluster
```

GitHub Actions has no Kubernetes API permissions. It assumes the AWS OIDC role only to push images to ECR. Argo CD performs CD from inside EKS. App Services are `ClusterIP`; the EKS API is private.

## Verified state (2026-11-22)

- GitHub Actions run for commit `930b14a` succeeded, including image build/scan/push and manifest update.
- Argo CD v3.6.1 Application `ivolve-devops` is `Synced` and `Healthy` from `main/k8s`.
- `auth-service`, `frontend`, and `roadmap-service` are Ready on image tag `930b14afc464f77976ca9a00fd42a4be4dcffd8e`.
- MySQL is running as StatefulSet `mysql`. PVC `mysql-data-mysql-0` is Bound to a 5 GiB encrypted gp3 EBS volume. Service `mysql` selects `mysql-stateful`.
- The source and restored `ivolve.users` row counts matched at zero. The entire `ivolve` database was dumped and restored before cutover. The old ephemeral MySQL Deployment is scaled to zero; the EBS-backed StatefulSet serves traffic.
- EKS has two `t3.small` workers with an 11-Pod limit each. The project uses one Argo Application and no Dex/OIDC SSO or notifications. The optional ApplicationSet, Notifications, and Dex deployments are scaled to zero; the bootstrap script preserves this capacity-aware configuration.
- No Ansible configuration exists in the repository.

## Jenkins retirement completed

The reviewed Terraform plan contained exactly 10 deletes: the Jenkins EC2, IAM role/profile and SSM attachment, key pair and security group, temporary EKS access entry/policy, `DescribeCluster` policy, and Jenkins-to-EKS ingress rule. It contained no changes to EKS, node groups, VPC, ECR, GitHub OIDC, or EBS resources. Applying the saved plan completed with `0 added, 0 changed, 10 destroyed`.

Post-apply AWS CLI verification confirmed:

- EC2 `i-0ddba871a9afde5cb` is `terminated`.
- EKS cluster `ivolve-devops-eks` remains `ACTIVE` with its API endpoint private.
- MySQL EBS volume `vol-02ffda242c6c0b421` remains `in-use`, encrypted, gp3, 5 GiB, and attached to an EKS worker.
- Terraform state no longer contains resources matching Jenkins or bootstrap access.

Argo CD and all workload pods were verified `Synced` / `Healthy` and Ready immediately before EC2 retirement. A post-retirement Kubernetes API check was not available from this workstation because the EKS API is private and the only in-VPC bootstrap EC2 has been terminated. The application Services remain internal (`ClusterIP`).

## Operational notes

- ECR repositories use immutable tags. CI reuses an existing image for a rerun of the same commit SHA.
- `app-secrets` remains a Kubernetes Secret. Never commit its values or place credentials in Terraform variables.
- The Argo CD UI is not exposed publicly.
