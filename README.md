# Cloud DevOps Project

An NTI and iVolve training project that packages a small microservices application and delivers it to Amazon EKS using Terraform, GitHub Actions, Amazon ECR, and Argo CD.

## Project status

- **CI/CD design:** GitHub Actions builds, scans, and publishes container images; Argo CD deploys them to EKS from the Kubernetes manifests in Git.
- **Application:** frontend, authentication, and roadmap services are deployed in Kubernetes namespace **ivolve**.
- **Database:** MySQL runs separately in **default** as a StatefulSet and stores its data on an encrypted, persistent EBS volume.
- **Network exposure:** the EKS API is private, and application Services are **ClusterIP**. There is no public application URL, Ingress, or LoadBalancer in this project configuration.
- **Architecture decision:** Jenkins and Ansible were excluded from the final implementation. GitHub Actions is used for CI and Argo CD for CD.

### Latest verification and AWS account status

The following checks were observed on **November 23, 2026**:

- The GitHub Actions workflow run manually started at commit **da531d1** completed successfully, including all three image jobs and the Argo CD manifest update job.
- Argo CD reported Application **ivolve-devops** as **Synced** and **Healthy**.
- **auth-service**, **frontend**, and **roadmap-service** each had one Ready Pod in **ivolve**.
- The MySQL StatefulSet was **1/1** Ready, and PVC **mysql-data-mysql-0** was **Bound**.
- A smoke test returned HTTP **302** for signup, **302** for login, and **200** for the authenticated Roadmap page. The temporary test account was deleted, and the PVC remained Bound.
- The retired zero-replica MySQL Deployment object was deleted; the MySQL StatefulSet and PVC were retained.

On **November 24, 2026**, the AWS sign-in page showed the account as suspended. The Billing and Cost Management Payments page showed **$0.00** outstanding and no payments due. The suspension reason was not established from those pages, and EKS has not been rechecked since the suspension appeared. AWS account support may need to resolve it before AWS resources or future deployments can be managed. See [AWS guidance for suspended accounts](https://repost.aws/knowledge-center/reactivate-suspended-account).

The repository remains available independently of AWS. Do not describe the live AWS application as currently reachable until the account is reactivated and the cluster is checked again.

## Architecture

~~~mermaid
flowchart LR
    Dev[Developer pushes to main] --> CI[GitHub Actions CI]
    CI --> Build[Build 3 container images]
    Build --> Scan[Trivy scan]
    Scan -->|pass| ECR[Amazon ECR immutable SHA tags]
    ECR --> Manifests[CI commits image tags to k8s/workloads.yaml]
    Manifests --> Argo[Argo CD watches main/k8s]
    Argo --> AppNS[Private EKS namespace ivolve]
    AppNS --> Frontend[Frontend :3000 ClusterIP]
    Frontend --> Auth[Auth Service :5000 ClusterIP]
    Frontend --> Roadmap[Roadmap Service :8080 ClusterIP]
    Auth --> MySQLService[mysql.default.svc.cluster.local:3306]
    MySQLService --> MySQL[MySQL StatefulSet in default]
    MySQL --> PVC[5 GiB encrypted gp3 EBS PVC]
    EKS[EKS private API and 2 worker nodes] --- Argo
    Terraform[Terraform] --> EKS
    Terraform --> ECR
    Terraform --> Network[VPC, subnets, NAT, Network ACL]
~~~

### Request flow

1. A user reaches the frontend on port **3000** from a network path inside the cluster or VPC.
2. The frontend forwards signup and login requests to the Auth Service on port **5000**.
3. The Auth Service stores users in the **ivolve** MySQL database. Passwords are stored as bcrypt hashes.
4. After login, the frontend keeps the user session in its Express session store.
5. The frontend requests roadmap data from the Roadmap Service on port **8080**.

Only the Auth Service connects directly to MySQL. The database, Auth Service, and Roadmap Service are not exposed publicly.

## Application components

| Component | Implementation | Container port | Responsibility |
|---|---|---:|---|
| Frontend | Node.js 22, Express 5, EJS | 3000 | Login/signup pages, session handling, and forwarding requests to backend services |
| Auth Service | Python 3.12, Flask, MySQL Connector, bcrypt | 5000 | User registration, login, password hashing, and MySQL access |
| Roadmap Service | Java 21, Spring Boot 3.5 | 8080 | Returns DevOps roadmap data |
| MySQL | MySQL 8.4 | 3306 | Stores records in the **ivolve.users** table |

### HTTP routes

| Service | Method | Route | Purpose |
|---|---|---|---|
| Frontend | GET | / | Login page, or redirect to Roadmap for a logged-in session |
| Frontend | GET | /signup | Signup page |
| Frontend | POST | /signup | Forwards signup data to Auth |
| Frontend | POST | /login | Forwards credentials to Auth and starts a frontend session |
| Frontend | GET | /roadmap | Authenticated Roadmap page |
| Frontend | POST | /logout | Ends the frontend session |
| Auth | GET | /health | Checks Auth and database readiness |
| Auth | POST | /api/auth/signup | Creates a user and bcrypt password hash |
| Auth | POST | /api/auth/login | Validates user credentials |
| Roadmap | GET | /api/roadmap | Returns roadmap data |

The frontend uses **AUTH_SERVICE_URL**, **ROADMAP_SERVICE_URL**, and **SESSION_SECRET**.

The Auth Service uses **DB_HOST**, **DB_PORT**, **DB_NAME**, **DB_USER**, and **DB_PASSWORD**.

## Repository layout

~~~text
.
├── auth-service/                   # Flask authentication service and Dockerfile
├── frontend/                       # Express/EJS web UI and Dockerfile
├── roadmap-service/                # Spring Boot roadmap API and Dockerfile
├── k8s/
│   ├── workloads.yaml              # Services and Deployments; app namespace is ivolve
│   └── storage.yaml                # Encrypted gp3 StorageClass and MySQL StatefulSet
├── argocd/
│   └── application.yaml            # Argo CD Application definition
├── terraform/
│   ├── bootstrap-state/             # Encrypted/versioned S3 state bucket setup
│   ├── environments/dev/            # Dev environment and remote backend
│   └── modules/                     # Network, ECR, and EKS modules
├── scripts/
│   ├── bootstrap-argocd.sh          # Installs Argo CD and applies the Application
│   ├── migrate-mysql-stateful.sh    # Backs up/restores MySQL to persistent EBS
│   ├── prepare-ivolve-namespace.sh  # Copies Secret keys to ivolve without printing values
│   └── update-image-tags.py         # Updates manifest tags to a Git SHA
├── .github/workflows/ci.yml         # Build, scan, push, and GitOps tag update
├── docker-compose.yml               # Local development stack
└── .env.example                     # Placeholder-only local environment template
~~~

## CI and GitOps deployment

### GitHub Actions CI

Workflow file: **.github/workflows/ci.yml** — **Build, scan, and publish images**.

On a push to **main**, the workflow runs when application code, **.dockerignore**, or the workflow itself changes. It can also be started with **workflow_dispatch**.

For each service, it:

1. Builds the Docker image using that service's Dockerfile.
2. Assumes an AWS IAM role through GitHub OIDC; no long-lived AWS access key is stored in GitHub.
3. Scans the image with Trivy for **HIGH** and **CRITICAL** findings that have fixes available. Findings matching the configured failure criteria fail the job.
4. Pushes the image to ECR with the full Git commit SHA as an immutable tag. A rerun reuses an image already published for the same SHA.

After all image jobs pass, the workflow updates **k8s/workloads.yaml** to use the SHA tag and pushes that manifest change to **main**. The required GitHub repository Actions variable is **AWS_ROLE_ARN**; it contains an IAM role ARN, not a password.

### Argo CD CD

**argocd/application.yaml** defines Application **ivolve-devops**. Argo CD runs inside the private cluster, watches the **k8s/** directory on **main**, and automatically syncs changes to namespace **ivolve**. Automated pruning and self-healing are enabled.

GitHub Actions does not have Kubernetes API access and does not directly deploy to EKS. EKS has a private-only API endpoint, so live cluster administration must come from an authorized host inside the VPC or a connected network.

### Current network exposure

- Kubernetes application Services use **ClusterIP**.
- No public Ingress or LoadBalancer is defined.
- The EKS API endpoint is private-only.
- The Argo CD UI is not publicly exposed.
- A public application URL has not been configured.

## Kubernetes and persistent data

- Application Deployments and Services run in namespace **ivolve**, one replica per service.
- The application Secret **app-secrets** exists in both **default** (for MySQL) and **ivolve** (for the Auth and Frontend pods). It contains **MYSQL_PASSWORD**, **MYSQL_ROOT_PASSWORD**, and **SESSION_SECRET**; values must never be committed or printed.
- The MySQL Service is **mysql** in namespace **default**. Application pods connect to **mysql.default.svc.cluster.local:3306**.
- MySQL runs as StatefulSet **mysql** in **default**.
- StorageClass **gp3-encrypted** provisions encrypted gp3 EBS volumes with reclaim policy **Retain**.
- The database PVC is **mysql-data-mysql-0**, sized 5 GiB. At the last check it was **Bound**.
- The database was backed up and restored to the EBS-backed StatefulSet before the MySQL Service was switched. The source and restored **users** row counts matched at migration.

The database data is not stored in the Git repository. A PVC has lifecycle and recovery implications: do not delete the PVC or its EBS volume when cleaning up unrelated Kubernetes resources.

## AWS infrastructure managed by Terraform

The development environment is defined in **terraform/environments/dev** and uses the modules under **terraform/modules**.

- **VPC:** CIDR **10.20.0.0/16**, two public subnets and two private subnets across two Availability Zones, Internet Gateway, and one NAT Gateway.
- **Network ACL:** Terraform-managed ACL associated with all four project subnets. It allows intra-VPC traffic and the configured web egress/return traffic.
- **EKS:** Kubernetes **1.35**, cluster API private-only, and a managed worker node group of two **t3.small** Amazon Linux 2023 nodes.
- **EKS add-ons:** Pod Identity Agent and AWS EBS CSI Driver. The CSI driver uses a dedicated IAM role for EBS volume management.
- **ECR:** one repository per application service, immutable tags, encryption, scan-on-push, and a lifecycle policy retaining the ten most recent images.
- **GitHub OIDC:** repository- and **main**-branch-scoped trust policy with ECR push permissions for CI.
- **Terraform state:** encrypted, versioned, public-access-blocked S3 backend with lockfile support.

Resources such as the EKS control plane, worker nodes, NAT Gateway, EBS volumes, ECR storage, and network data transfer can incur AWS charges. The project has no public LoadBalancer configured.

The infrastructure is account-specific. Recreating it in another AWS account requires a compatible Terraform state backend, AWS OIDC trust and IAM role, GitHub **AWS_ROLE_ARN** variable, and matching ECR registry references. The MySQL PVC in one AWS account does not automatically move to another account.

## Run locally with Docker Compose

Requirements: Docker Desktop with Docker Compose enabled.

From the repository root, create a private local environment file from the placeholders:

~~~powershell
Copy-Item .env.example .env
~~~

Edit **.env** and set unique local values for all passwords and the session secret. Do not commit **.env**; it is ignored by **.gitignore**.

Start the stack:

~~~powershell
docker compose up --build -d
docker compose ps
~~~

Open **http://localhost:3000** in a browser. Docker Compose publishes only the Frontend port to the host; backend services and MySQL stay on the internal Compose network.

Stop the stack while keeping the local MySQL named volume:

~~~powershell
docker compose down
~~~

Deleting the Compose volume removes the local database contents. Do not add the **-v** option unless you intend to discard that local data.

## Terraform workflow

Terraform changes affect real AWS resources and may incur cost. Review the full plan before applying infrastructure changes. The backend bucket must already exist; its setup code is under **terraform/bootstrap-state**.

~~~powershell
Set-Location terraform/environments/dev
$env:AWS_PROFILE = "root-dev"
terraform init
terraform validate
terraform plan -out=review.tfplan
terraform show -no-color review.tfplan
~~~

Only apply a reviewed plan when the AWS account is active and the intended changes are understood:

~~~powershell
terraform apply review.tfplan
~~~

Never commit Terraform state, saved plans, credentials, **.tfvars** files containing secrets, or real **.env** values.

## Operational checks

Run these commands in AWS CloudShell with connectivity to the cluster VPC, or another authorized in-VPC host:

~~~bash
source kubectl-connect ivolve-devops-eks --region us-east-1
kubectl get application ivolve-devops -n argocd
kubectl get deployments,pods,services -n ivolve
kubectl get statefulsets,pvc,services -n default
~~~

Expected healthy state:

- Argo CD Application is **Synced** and **Healthy**.
- All three application Deployments and Pods are Ready in namespace **ivolve**.
- MySQL StatefulSet is Ready in **default**.
- PVC **mysql-data-mysql-0** is **Bound**.
- The retired Deployment object named **mysql** is absent; the StatefulSet is the database workload.

The local machine's normal kubeconfig may not reach this cluster because the EKS endpoint is private. CloudShell sessions are temporary; reconnect and source **kubectl-connect** in each new session.

## Security and known limitations

- Do not commit AWS credentials, GitHub tokens, database passwords, session-secret values, Terraform state, or actual **.env** files.
- Kubernetes credentials are read from **app-secrets**; the manifests refer to Secret keys without embedding values.
- GitHub Actions uses OIDC with scoped ECR permissions instead of long-lived AWS keys.
- Auth hashes passwords with bcrypt. MySQL and the backend APIs remain private.
- The application uses Express's in-memory session store and one frontend replica. This is suitable for a small demonstration, not a horizontally scaled production session architecture.
- The current internal-only app has no public URL or TLS endpoint.
- AWS account suspension was shown on November 24, 2026 even though the Payments page showed no outstanding balance. The suspension reason is unknown; current EKS reachability and future AWS deployments need revalidation after AWS resolves the account status.

## User-approved scope choices

The initial training brief included Jenkins, Ansible, and externally reachable application components. The final architecture followed the later project decision:

- GitHub Actions is CI.
- Argo CD is CD.
- Jenkins and its EC2 host were retired.
- Ansible configuration was not retained.
- Application Services and the EKS API remain private.
- Existing MySQL data was retained on encrypted EBS-backed storage while application workloads moved to namespace **ivolve**.

These choices define the delivered project scope; explain them during handoff if they differ from the original brief.
