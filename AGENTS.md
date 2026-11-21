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
- The existing Jenkins EC2 is retained only as a temporary in-VPC bootstrap/migration host. Retire its EC2, IAM access, and security-group rule only after MySQL data is on EBS and Argo CD has synced and been verified.
- Keep the EKS API private. Keep application Services internal (`ClusterIP`).

## Safety and state

- Never hardcode or commit credentials or database passwords.
- Preserve existing MySQL data when moving from the ephemeral Deployment to the EBS-backed StatefulSet. Verify the restored row count before switching the service.
- Never run `terraform apply` or `terraform destroy` without explicit user approval. Review plans and identify destroys first.
- Do not terminate the temporary EC2 or remove its EKS access before the Argo CD bootstrap and database migration are complete.

## Verified application facts

- `frontend/`: Node.js 22, Express/EJS, port 3000; calls Auth and Roadmap through `AUTH_SERVICE_URL` and `ROADMAP_SERVICE_URL`.
- `auth-service/`: Python 3.12 / Flask, port 5000; uses MySQL and `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME`; `/health` is available.
- `roadmap-service/`: Java 21 / Spring Boot, port 8080; `GET /api/roadmap`; no database dependency.
- Only Auth accesses MySQL. Keep MySQL private.

## Progress and known validation limits

- Docker/Compose, Terraform, Kubernetes, ECR, GitHub Actions and EKS files exist. The application has previously been deployed successfully to EKS through GitHub Actions.
- The current local MySQL-to-EBS migration and EBS CSI add-on changes are pending validation/application. Do not claim the MySQL migration is complete until it is observed in the cluster.
- The cluster endpoint is private-only. Kubernetes bootstrap commands must run from an authorized host inside the VPC or a connected network.
