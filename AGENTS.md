# Cloud DevOps Project Guidance

## Working preferences

- Start with a plain-language explanation of the purpose, then give ordered, runnable steps.
- Inspect source code and actual command output before choosing ports, endpoints, environment variables, or dependencies.
- Keep changes modular and readable, explain significant choices, and report unrun checks or failures honestly.
- For documentation requests, favor README-ready English deliverables and explicit command/file lists. In conversation, clear concise Arabic is appropriate when the user uses Arabic.
- Do not expose secrets. Use safe templates and placeholders.

These preferences come from a limited review of locally available Codex threads about Ansible, Kubernetes, and Jenkins. Unrelated conversation details are intentionally excluded.

## Project decisions and guardrails

- Work in phases. Phase 1 source inspection and architecture analysis must precede all implementation phases.
- Use the actual application source as authority over its inaccurate upstream README where they differ.
- Jenkins is CI; GitHub Actions is CD to EKS using GitHub OIDC. The NTI PDF asks for ArgoCD, but the user's explicit project decision overrides that item: do not install, configure, or use ArgoCD.
- Do not hardcode or commit credentials or database passwords. Do not run `terraform apply` or `terraform destroy` without explicit approval.
- Avoid business logic changes unless needed for the requested deployment architecture; explain and isolate any such change.
- Never claim a validation passed unless it was run and passed.

## Application facts verified from source

- `frontend/`: Node.js 22 Alpine image, Express 5, EJS, listens on port 3000; calls `AUTH_SERVICE_URL` and `ROADMAP_SERVICE_URL`; uses express-session with a weak fallback secret and the default in-memory store.
- `auth-service/`: Python 3.12, Flask, bcrypt, mysql-connector-python; listens on port 5000; requires `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME`; exposes `/health`, `/api/auth/signup`, `/api/auth/login`; creates the `users` table at runtime; only service that accesses MySQL.
- `roadmap-service/`: Java 21 / Spring Boot 3.5.4; listens on port 8080; exposes `GET /api/roadmap`; returns static roadmap data and has no database dependency or configured health endpoint.
- At the Phase 1 source snapshot, Dockerfiles existed for all three services, but Compose, Kubernetes, Terraform, Ansible, CI/CD, and deployment manifests did not. Phase 2 adds Compose and container build configuration.
- The upstream README misidentifies Auth and Roadmap languages, lists example APIs that differ from source, and includes a plaintext-looking sample DB password. Do not repeat that value; replace such examples with placeholders in later documentation.

## Progress

- [x] Review local conversation history and project requirements.
- [x] Phase 1: inspect application source and record architecture, gaps, and the implementation plan in `PHASE1_ARCHITECTURE.md`.
- [x] Phase 2: Docker/Compose implementation complete. Compose config and npm lock consistency passed; image build and runtime validation were attempted but blocked because Docker Desktop's Linux engine is inaccessible from this session.
- [ ] Phase 3: Terraform.
- [ ] Phase 4: Ansible.
- [ ] Phase 5: Kubernetes.
- [ ] Phase 6: Jenkins CI.
- [ ] Phase 7: GitHub Actions CD.
- [ ] Phase 8: final documentation and validation.
