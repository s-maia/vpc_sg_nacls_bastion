🔭 Secure & Scalable Multi-Tier VPC Foundation for a 3-Tier App

This project delivers a fully automated Multi-Tier VPC Foundation using modular Terraform and GitHub Actions (GitOps). The infrastructure is secure, scalable, and environment-aware (dev/staging/production).

Implements a production-grade 3-tier layout (Public / Private-App / Private-Data) across 2 AZs, with bastion access, NAT egress, and tight Security Groups and NACLs.


🔭 Objectives

- Build a new VPC from scratch spanning at least two AZs.
- Create three subnet tiers per AZ: Public (LB/Bastion), Private-App (app servers), Private-Data (databases).
- Configure IGW + NAT Gateways for private egress.
- Implement least-privilege Security Groups and NACLs.
- Provide a Bastion host for controlled admin access to private tiers.
- Automate with Terraform + GitHub Actions using remote state in S3.


Repository layout
.
├── .github/workflows/        # CI/CD pipelines
├── bastion/                  # Bastion module (EC2, IAM role/profile, SG)
│   ├── bastion_iam.tf
│   ├── locals.tf
│   ├── resources.tf
│   └── variables.tf
├── vpc/                      # VPC module (VPC, subnets, RTs, IGW, NAT, NACLs, SGs)
│   ├── locals.tf
│   ├── outputs.tf
│   ├── resources.tf
│   └── variables.tf
└── infra-root/               # Root module (wires modules + backend/vars)
    ├── dev.tfvars
    ├── staging.tfvars
    ├── production.tfvars
    ├── main.tf
    ├── provider.tf
    ├── variables.tf
    └── README.md  (this file)


📦  <What gets created>
1) VPC with DNS support
2) Subnets per AZ: Public, Private-App, Private-Data
3) Routing: Public RT → IGW; App/Data RTs → NAT GW in the same AZ
4) IGW, 2× NAT Gateways (one per AZ) + EIPs
5) Network ACLs (public/app/data) with explicit ingress/egress
6) Security Groups:
    * alb_sg — ingress 443 from Internet; egress to App
    * app_sg — ingress 80/443 from ALB and 22 from Bastion; egress 443 to Internet (via NAT) and 5432 to DB
    * db_sg — ingress 5432 only from App; minimal egress
    * bastion_sg — ingress 22 from admin IP(s); egress 22 to App and 80/443 to Internet
7) Bastion EC2 (Amazon Linux 2023) with IAM Role/Instance Profile (SSM Core), tags, and SG wiring


🔐  <Security groups>

* ALB SG
Ingress: 443 from 0.0.0.0/0
Egress: to App SG (80/443)

* App SG
Ingress: 80/443 from ALB SG; 22 from Bastion SG
Egress: 443 to Internet (via NAT) and 5432 to DB SG

* DB SG
Ingress: 5432 from App SG only (no Internet)

* Bastion SG
Ingress: 22 from admin IPs (e.g., 45.30.54.169/32)
Egress: 22 to App SG; 80/443 to Internet


🔒 <NACLs (stateless)>

* Public NACL — In: 80/443 from Internet; Out: ephemeral 1024–65535

* App NACL — In: 80/443 from Public; 22 from Bastion. Out: 443 to Internet via NAT + ephemeral return

* Data NACL — In: 5432 from App; Out: ephemeral return


Note: NACLs are stateless: always allow the return ephemeral ports on the opposite side.



⚙️ CI/CD (GitHub Actions)

Pipeline runs init → fmt → plan → apply (when enabled).
Remote state is stored in S3 with a bucket per account/stage.

Main workflow: .github/workflows/deploy-infra.yaml

Env vars (GitHub → Environments → production/staging/dev):
   - AWS_REGION (e.g., us-east-1)
   - ENVIRONMENT_STAGE (dev | staging | production)

Secrets:
   - IAM_ROLE — the role to assume from GitHub OIDC
   - AWS_ACCOUNT_ID - the aws account where infra is createad

Backend naming:
   - Defaults to: s3://<ACCOUNT>-state-bucket-<ENVIRONMENT_STAGE>/terraform.tfstate



▶️ Run
How branches map to environments

Your workflow sets the GitHub Environment based on the branch:   
   environment: ${{ (github.ref == 'refs/heads/main' && 'production') || (github.ref == 'refs/heads/staging' && 'staging') || 'dev' }}


Push to feature/* → uses dev environment → ENVIRONMENT_STAGE=dev → dev.tfvars.

Push to staging → uses staging environment → ENVIRONMENT_STAGE=staging → staging.tfvars.

Push to main → uses production environment → ENVIRONMENT_STAGE=production → production.tfvars.


🚀 Required approvals & checks (staging/production)

Merging to staging or main requires 3 PR approvals (branch protection).

All required status checks must pass (e.g., Terraform fmt/plan, tests) before the PR can be approved/merged.

If Environment required reviewers are configured for staging/production, the workflow pauses at deployment time until reviewers approve.


** Flow **

1) Work on a feature branch

Create feature/<name> and push commits.

Pushes to feature/* target the dev environment automatically (via
environment: ${{ (github.ref == 'refs/heads/main' && 'production') || (github.ref == 'refs/heads/staging' && 'staging') || 'dev' }}).

Review the Terraform plan and, if your process allows, run apply for dev (manual workflow_dispatch action=apply).

Validate the change end-to-end in dev until it looks good.

2) Open a PR into staging

This promotes your change toward the staging environment.

3) Ensure all required checks pass

e.g., Terraform fmt/plan, linters, unit tests, etc.

4) Obtain 3 approvals (staging)

Branch protection requires 3 PR approvals before merging to staging.

5) Merge → push triggers the staging workflow

The pipeline runs for staging. If you use Environment required reviewers, the job will pause there until approved.

6) Promote to production

Open a PR from staging → main.

All required checks must pass and get 3 approvals again.

Merge → push triggers the production workflow.