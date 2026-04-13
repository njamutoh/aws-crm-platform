# AWS CRM Platform with Terraform and CI/CD

![AWS](https://img.shields.io/badge/AWS-Cloud%20Platform-232F3E?logo=amazonaws&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-IaC-844FBA?logo=terraform&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-Containerized-2496ED?logo=docker&logoColor=white)
![Node.js](https://img.shields.io/badge/Node.js-Backend-339933?logo=nodedotjs&logoColor=white)
![MySQL](https://img.shields.io/badge/MySQL-Database-4479A1?logo=mysql&logoColor=white)
![CodePipeline](https://img.shields.io/badge/AWS-CodePipeline-FF9900?logo=amazonaws&logoColor=white)

## Table of Contents
- [Overview](#overview)
- [Business Problem](#business-problem)
- [Architecture Diagram](#architecture-diagram)
- [Architecture Summary](#architecture-summary)
- [AWS Services Used](#aws-services-used)
- [Repository Structure](#repository-structure)
- [Terraform Code Structure](#terraform-code-structure)
- [Terraform Module Design](#terraform-module-design)
- [CI/CD Workflow](#cicd-workflow)
- [Security Design](#security-design)
- [Deployment Challenges Solved](#deployment-challenges-solved)
- [Quick Start](#quick-start)
- [Demo Credentials](#demo-credentials)
- [What I Learned](#what-i-learned)
- [Future Improvements](#future-improvements)

---

## Overview

After three weeks of working on a client CRM platform, I designed and deployed a production-grade AWS environment to solve a real business problem affecting day-to-day sales operations.

The client was dealing with fragmented customer data, duplicate records across teams, weak visibility into pipeline performance, and inconsistent follow-up on active opportunities. Those issues were reducing reporting accuracy, slowing execution, and creating revenue leakage.

To address that, I built a production-style three-tier AWS CRM platform using Terraform for infrastructure as code and AWS native CI/CD services for automated delivery. The platform was designed not only to provision successfully, but to be deployed, debugged, secured, and stabilized under real operating conditions.

---

## Business Problem

The client environment had several operational issues:

- Fragmented customer data across teams
- Duplicate customer records affecting reporting accuracy
- Poor visibility into sales pipeline health
- Missed follow-ups on active opportunities
- Operational inefficiencies translating into revenue loss

This project was implemented as a real solution to address those challenges through a secure and automated cloud platform.

---

## Architecture Diagram

> Replace the image path below with your uploaded architecture diagram.

```md
![AWS CRM Platform Architecture](docs/architecture-diagram.png)
```

---

## Architecture Summary

The platform follows a three-tier architecture:

### Edge Layer
- Route 53 for DNS
- CloudFront for content delivery
- AWS WAF for edge protection
- Application Load Balancer for traffic distribution

### Application Layer
- Launch Template for EC2 configuration
- Auto Scaling Group for elasticity
- EC2 instances for application hosting
- Dockerized Node.js / Express CRM application

### Data Layer
- Amazon RDS MySQL as the relational database
- AWS Secrets Manager for runtime secrets
- AWS KMS for encryption and decryption control

This architecture was provisioned using modular Terraform code to keep responsibilities separated, reusable, and easier to manage.

---

## AWS Services Used

- Amazon VPC
- Public and private subnets
- Route 53
- CloudFront
- AWS WAF
- Application Load Balancer
- Amazon EC2
- Auto Scaling Group
- Launch Templates
- Amazon RDS MySQL
- AWS Secrets Manager
- AWS KMS
- Amazon ECR
- AWS CodePipeline
- AWS CodeBuild
- AWS CodeDeploy
- Amazon S3
- DynamoDB
- IAM
- CloudWatch

---

## Repository Structure

```text
.
├── app/
│   ├── appspec.yml
│   ├── buildspec.yml
│   ├── schema.sql
│   ├── server.js
│   └── scripts/
│       └── deploy.sh
└── infra/
    ├── backend.tf
    ├── module-call.tf
    ├── outputs.tf
    ├── provider.tf
    ├── terraform.tfvars
    ├── variables.tf
    ├── bootstrap/
    │   ├── backend.tf
    │   └── provider.tf
    └── modules/
        ├── compute/
        │   ├── main.tf
        │   ├── output.tf
        │   ├── variable.tf
        │   └── scripts/
        │       └── userdata.sh
        ├── database/
        │   ├── main.tf
        │   ├── output.tf
        │   └── variable.tf
        ├── delivery/
        │   ├── main.tf
        │   ├── output.tf
        │   └── variables.tf
        ├── network/
        │   ├── main.tf
        │   ├── output.tf
        │   └── variable.tf
        ├── security/
        │   ├── main.tf
        │   ├── output.tf
        │   └── variable.tf
        └── traffic-entry/
            ├── main.tf
            ├── output.tf
            └── variable.tf
```

---

## Terraform Code Structure

The Terraform code is split into a root layer, a bootstrap layer, and reusable modules.

### Root Layer

```text
infra/
├── backend.tf
├── provider.tf
├── variables.tf
├── terraform.tfvars
├── outputs.tf
└── module-call.tf
```

### Root File Responsibilities

- `backend.tf`: configures remote state backend
- `provider.tf`: defines AWS provider configuration
- `variables.tf`: declares root input variables
- `terraform.tfvars`: provides environment-specific values
- `outputs.tf`: exposes root outputs
- `module-call.tf`: wires modules together

### Bootstrap Layer

The backend infrastructure for Terraform state is managed separately from the main stack.

```text
infra/bootstrap/
├── backend.tf
└── provider.tf
```

Typical bootstrap responsibilities:
- Create the S3 bucket for Terraform state
- Create the DynamoDB table for state locking

### Module Layout

```text
infra/modules/
├── network/
├── security/
├── traffic-entry/
├── compute/
├── database/
└── delivery/
```

### Module File Pattern

Each module follows a consistent pattern:

```text
module-name/
├── main.tf
├── output.tf
└── variable.tf
```

Or, in one module:

```text
delivery/
├── main.tf
├── output.tf
└── variables.tf
```

This keeps the code modular, easier to reason about, and easier to extend.

---

## Terraform Module Design

### `network`
Responsible for:
- VPC creation
- Public and private subnet layout
- Route tables and networking foundation

### `security`
Responsible for:
- Security groups
- Layered access rules between ALB, EC2, and RDS
- Traffic boundaries across tiers

### `traffic-entry`
Responsible for:
- Route 53 configuration
- CloudFront distribution
- ALB, listeners, and target groups
- WAF association when enabled

### `compute`
Responsible for:
- AMI lookup
- IAM instance role and profile
- Launch Template
- Auto Scaling Group
- EC2 bootstrap via user data

### `database`
Responsible for:
- RDS primary and replica configuration
- DB subnet group
- Parameter group
- Secrets Manager secret
- KMS key and alias

### `delivery`
Responsible for:
- Amazon ECR repository
- S3 artifact bucket
- CodeBuild project
- CodeDeploy application and deployment group
- CodePipeline orchestration

---

## CI/CD Workflow

The application delivery flow is:

```text
GitHub
  -> CodePipeline
    -> CodeBuild
      -> Amazon ECR
        -> CodeDeploy
          -> EC2 Auto Scaling Group
```

### Delivery Stages

1. Source code is pushed to GitHub.
2. CodePipeline pulls the latest revision.
3. CodeBuild builds the Docker image.
4. The image is pushed to Amazon ECR.
5. Build artifacts are passed to CodeDeploy.
6. CodeDeploy runs lifecycle hooks on EC2 instances.
7. The application is started and validated through health checks.

---

## Security Design

Security was built into the platform from the start:

- Secrets stored in AWS Secrets Manager
- Secrets encrypted with a customer-managed KMS key
- IAM roles scoped to service responsibilities
- RDS deployed in private subnets
- Security groups isolating edge, app, and data tiers
- EC2 instances configured for IMDSv2-compatible metadata access
- Controlled runtime secret retrieval during deployment

---

## Deployment Challenges Solved

This project became most valuable during troubleshooting, because the platform had to be stabilized across several service boundaries.

### Issues Encountered

- ALB health failures leading to `502` errors
- Auto Scaling refresh instability
- CodeDeploy deployment failures
- Missing ECR image pushes
- CodeBuild YAML parsing problems
- Working directory leakage between CodeBuild phases
- Docker Hub rate limiting
- Missing static asset paths during build
- EC2 bootstrap failure caused by IMDSv2 enforcement
- CodeDeploy agent installation failures
- Secrets Manager reference mismatch in deployment scripts
- KMS decrypt permission failures on the EC2 role
- Database schema initialization gaps
- Authentication failures caused by runtime and data-state issues

### Fixes Implemented

- Corrected buildspec structure and command formatting
- Isolated CodeBuild phase paths correctly
- Switched image sourcing to avoid Docker Hub rate limits
- Fixed deployment artifact layout
- Updated user data for IMDSv2 token retrieval
- Corrected deployment secret references
- Added KMS decrypt permissions to the EC2 role
- Added runtime schema initialization logic
- Added demo-user self-healing logic
- Validated the platform end to end after deployment

---

## Quick Start

### 1. Bootstrap the Terraform Backend

```bash
cd infra/bootstrap
terraform init
terraform apply
```

### 2. Deploy the Main Infrastructure

```bash
cd ../
terraform init
terraform plan
terraform apply
```

### 3. Trigger Application Delivery

Push changes to the connected GitHub repository so CodePipeline can build and deploy the application automatically.

### 4. Validate the Deployment

Check the following after deployment:

- CodePipeline execution status
- CodeBuild logs
- CodeDeploy lifecycle events
- ALB target health
- Application health endpoint

---

## Demo Credentials

```text
Email: demo@nexuscrm.io
Password: Demo1234!
```

---

## What I Learned

This project reinforced several practical lessons:

- Provisioning infrastructure is only the first step
- Delivery failures often span multiple AWS services
- Secrets access is incomplete without correct KMS permissions
- Instance bootstrap must match the security model
- Infrastructure readiness does not guarantee application readiness
- Production engineering requires debugging across IAM, networking, deployment automation, runtime behavior, and data state

---

## Future Improvements

- Add observability dashboards and alarms
- Introduce blue/green deployments
- Add automated integration tests in the pipeline
- Improve structured logging and tracing
- Add secret rotation workflows
- Expand WAF protections
- Add DR validation and backup recovery testing
- Evolve the app tier toward ECS or EKS for larger-scale orchestration
