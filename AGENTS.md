# Project Guidance

## Working preferences

- Explain the goal before the commands, and give small ordered steps with expected results.
- Inspect the repository and actual command output before choosing ports, endpoints, dependencies, or configuration.
- Do not expose credentials. Use environment variables, Kubernetes Secrets, and ignored local files.
- Report checks as actually observed. Do not claim an unrun build, test, plan, or deployment succeeded.
- Keep application business logic unchanged unless a deployment requirement makes a small change necessary.

## Current delivery architecture

- GitHub Actions performs CI: build the three service images, scan them with Trivy, push immutable Git-SHA tags to ECR, and commit those image tags to `k8s/workloads.yaml`.
- Argo CD performs CD: it watches the `k8s/` directory in the `main` branch and syncs the private EKS cluster.
- Do not use Jenkins for CI or GitHub Actions for direct Kubernetes deployment.
- Jenkins and Ansible are not part of the target architecture. There is no Ansible configuration in this repository.
- The former Jenkins EC2, its IAM access, and its EKS security-group route have been removed with Terraform. The EKS API is private, so live Kubernetes inspection now requires an authorized connection inside the VPC.
- Kubernetes application Deployments/Services and the app ConfigMap are deployed in namespace `ivolve`; the three application Pods were confirmed `1/1` Ready on Argo CD revision `1f80d2d`. Keep MySQL and its Service, Secret, ConfigMap, StatefulSet, and PVC in `default`. The `app-secrets` Secret was copied into `ivolve` and its key names verified.
- Terraform manages restrictive Network ACL `acl-0dc0f5192d6438c08`, associated with all four public/private subnets. It allows intra-VPC traffic, outbound TCP 80/443, and inbound TCP ephemeral return traffic; unmatched IPv4 traffic is denied by the AWS default rule.
- Keep the EKS API private. Keep application Services internal (`ClusterIP`).

## Safety and state

- Never hardcode or commit credentials or database passwords.
- Preserve existing MySQL data when moving from the ephemeral Deployment to the EBS-backed StatefulSet. Verify the restored row count before switching the service.
- Never run `terraform apply` or `terraform destroy` without explicit user approval. Review plans and identify destroys first.
- The former EC2 retirement, application namespace move, and Network ACL rollout are complete. Keep the EKS endpoint private and preserve the retained MySQL EBS volume.

## Verified application facts

- `frontend/`: Node.js 22, Express/EJS, port 3000; calls Auth and Roadmap through `AUTH_SERVICE_URL` and `ROADMAP_SERVICE_URL`.
- `auth-service/`: Python 3.12 / Flask, port 5000; uses MySQL and `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME`; `/health` is available.
- `roadmap-service/`: Java 21 / Spring Boot, port 8080; `GET /api/roadmap`; no database dependency.
- Only Auth accesses MySQL. Keep MySQL private.

## Progress and known validation limits

- Docker/Compose, Terraform, Kubernetes, ECR, GitHub Actions and EKS files exist. The application has previously been deployed successfully to EKS through GitHub Actions.
- MySQL migration is complete: the 5 GiB encrypted EBS PVC is Bound, StatefulSet/mysql is Ready, service/mysql selects mysql-stateful, and the restored users row count matches the source (0).
- Before retiring the bootstrap host, Argo CD Application ivolve-devops was Synced and Healthy; auth-service, frontend, roadmap-service, and mysql pods were Ready. After retirement, AWS CLI confirmed the Jenkins EC2 is terminated, EKS remains ACTIVE, and the 5 GiB encrypted gp3 MySQL volume remains in-use on an EKS worker. The approved retirement plan made no changes to EKS, VPC, ECR, GitHub OIDC, or EBS resources.
- Namespace commit `1f80d2d` is pushed. CloudShell VPC verified Argo CD `Synced` / `Healthy`, all three app Deployments/Pods `1/1` Ready in `ivolve`, and the MySQL StatefulSet/PVC remains in `default` and Bound. A retired Deployment named `mysql` remains scaled to zero (`0/0`); the StatefulSet serves the database. The restrictive ACL is applied and associated with all four subnets.
- The cluster endpoint is private-only. Kubernetes bootstrap commands must run from an authorized host inside the VPC or a connected network.
