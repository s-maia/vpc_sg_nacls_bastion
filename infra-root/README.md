🔭 Secure & Scalable Multi-Tier VPC Foundation for a 3-Tier App

This project delivers a fully automated Multi-Tier VPC Foundation using modules written from scratch in Terraform code and GitHub Actions (GitOps). The infrastructure is secure, scalable, and environment-aware (dev/staging/production).

Implements a production-grade 3-tier layout (Public / Private-App / Private-Data) across 2 AZs, with bastion access, NAT gateway, and tight Security Groups and NACLs.


🔭 Objectives

- Build a new VPC from scratch spanning at least two AZs.
- Create three subnet tiers per AZ: Public (LB/Bastion), Private-App (app servers), Private-Data (databases).
- Configure IGW + NAT Gateways for private egress.
- Implement least-privilege Security Groups and NACLs.
- Provide a Bastion host for controlled admin access to private tiers.
- I Automated with Terraform + GitHub Actions and also used remote state in S3.

   
Repository layout
 
.
├── .github/
│   └── workflows/
│       └── deploy-infra.yaml
├── bastion/
│   ├── locals.tf
│   ├── resources.tf
│   └── variables.tf
├── infra-root/
│   ├── .terraform/
│   ├── .terraform.lock.hcl
│   ├── dev.tfvars
│   ├── main.tf
│   ├── production.tfvars
│   ├── provider.tf
│   ├── README.md
│   ├── staging.tfvars
│   └── variables.tf
├── vpc/
│   ├── locals.tf
│   ├── outputs.tf
│   ├── resources.tf
│   └── variables.tf
└── .gitignore



📦  <What gets created>
1) VPC with DNS support
2) Subnets per AZ: Public, Private-App, Private-Data
3) Routing: Public RT → IGW; App RTs → NAT in same AZ; Data RTs no internet
4) IGW, 2× NAT Gateways (one per AZ) + EIPs
5) NACLs: public/app/data with explicit allow rules (stateless)
6) Security Groups:
    * alb_sg — ingress 443 from Internet; egress 443 to App SG
    * app_sg — ingress 443 from ALB SG + 22 from Bastion SG; egress 443 to Internet (via NAT) + 5432 to DB SG
    * db_sg — ingress 5432 only from App SG; no egress (most restrictive)
    * bastion_sg — ingress 22 from admin_cidrs; egress 22 to App SG + 80/443 to Internet (updates)
7) Bastion EC2 (Amazon Linux 2023), key-only SSH,IMDSv2 required, SSH password auth disabled via user_data


🔐  <Security groups>

* ALB SG
Ingress: 443 from 0.0.0.0/0
Egress: 443 to app_sg (ALB → App TLS)

* App SG
Ingress: 443 from alb_sg, 22 from bastion_sg
Egress: 443 to Internet (via NAT), 5432 to db_sg

* DB SG
Ingress: 5432 from app_sg only
Egress: none (isolation)

* Bastion SG
Ingress: 22 from admin_cidrs (my home IP /32)
Egress: 22 to app_sg, 80/443 to Internet (updates, repos)


🔒 <NACLs (stateless)>

* Inbound: 80/443 from Internet; 22 from admin_cidrs; ephemeral 1024–65535 from Internet (return traffic); 
  Outbound: 80/443 to Internet; 443 to VPC (ALB→App); ephemeral 1024–65535 to Internet


* Inbound: 443 from VPC (ALB), 22 from VPC (Bastion), ephemeral from VPC
  Outbound: 80/443 to Internet (via NAT), 5432 to VPC (DB), ephemeral to VPC

* Inbound: 5432 from VPC (App)
  Outbound: ephemeral to VPC (DB responses)


Note: Because NACLs are stateless, the return path must be explicitly allowed (that’s why the ephemeral rules exist).



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


<How to deploy infrastructure>

1) Work on a feature branch

Create feature/<name> and push commits.

Pushes to feature/* target the dev environment automatically (via
environment: ${{ (github.ref == 'refs/heads/main' && 'production') || (github.ref == 'refs/heads/staging' && 'staging') || 'dev' }}).

Review the Terraform plan and, if your process allows, run apply for dev (manual workflow_dispatch action=apply).

Validate the change end-to-end in dev until it looks good.

2) Open a PR into staging/production

This promotes your change toward the staging environment.

3) Ensure all required checks pass

e.g., Terraform fmt/plan, unit tests, etc.

4) Obtain 3 approvals (staging/production)

Branch protection requires 3 PR approvals before merging to staging/production.

5) Merge 

