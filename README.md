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
- [How the Infrastructure Works](#how-the-infrastructure-works)
- [AWS Services Used](#aws-services-used)
- [Repository Structure](#repository-structure)
- [Terraform Code Structure](#terraform-code-structure)
- [Terraform Module Design](#terraform-module-design)
- [Source to Deployment Flow](#source-to-deployment-flow)
- [Application and Demo Login Flow](#application-and-demo-login-flow)
- [Security Design](#security-design)
- [Logging and Operational Visibility](#logging-and-operational-visibility)
- [Deployment Challenges Solved](#deployment-challenges-solved)
- [Quick Start](#quick-start)
- [Demo Credentials](#demo-credentials)
- [What I Learned](#what-i-learned)
- [Future Improvements](#future-improvements)

---

## Overview

After three weeks of working on a client CRM platform, I designed and deployed a production-grade AWS environment to solve a real business problem affecting day-to-day sales operations.

The client was dealing with fragmented customer data, duplicate records across teams, weak pipeline visibility, and inconsistent follow-up on active opportunities. Those issues were reducing reporting accuracy, slowing execution, and creating revenue leakage. The goal of this project was to build a secure, automated, and production-style CRM platform that could support real deployment workflows instead of just serving as a static architecture exercise.

I implemented the platform as a three-tier AWS environment using Terraform for infrastructure as code and AWS native delivery services for CI/CD. The work covered networking, traffic entry, compute, database provisioning, secrets management, deployment automation, runtime debugging, and recovery. A large part of the value came from taking the platform beyond provisioning and stabilizing it through multiple failures across build, deploy, IAM, and application runtime layers.

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

![AWS CRM Platform Architecture](infra/Architecture%20diagram.png)

---

## Architecture Summary

The platform follows a classic three-tier architecture, with clear separation between edge, application, and data layers.

### Edge Layer
- Route 53 provides DNS resolution for the application domain
- CloudFront sits at the edge to improve delivery and front the platform
- AWS WAF can be attached for request filtering and protection
- Application Load Balancer receives and distributes incoming traffic

### Application Layer
- EC2 instances run the CRM application
- Instances are managed by an Auto Scaling Group for elasticity and replacement
- A Launch Template defines how new instances are created
- The Node.js/Express application is deployed as a Docker container
- CodeDeploy handles application rollout to the EC2 instances

### Data Layer
- Amazon RDS MySQL stores the CRM data
- AWS Secrets Manager stores database credentials and runtime secrets
- AWS KMS encrypts sensitive values and controls decryption access

This layout makes it easier to isolate responsibilities. Edge services handle entry and routing, compute handles business logic and deployments, and the data layer remains private and protected.

---

## How the Infrastructure Works

At a high level, the infrastructure works by separating public traffic from private application and database resources.

A user accesses the CRM through the public endpoint. Traffic enters through Route 53 and CloudFront, then reaches the Application Load Balancer. The load balancer forwards requests only to healthy EC2 instances in the application tier. Those EC2 instances run the Dockerized CRM backend and communicate with the private RDS MySQL database.

The platform is designed so that:
- Public access is limited to the edge and load balancer layer
- Application instances operate in a controlled tier with scoped security group access
- The database remains isolated from direct public access
- Secrets are not hardcoded in the application or Terraform outputs
- Deployment automation can replace or refresh application instances without manually rebuilding the environment

This creates a cleaner operational model: infrastructure provisioning is repeatable, deployments are automated, and the application runtime depends on managed AWS services rather than local configuration drift.

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
    ├── Architecture diagram.png
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

- `backend.tf`: configures the remote Terraform backend
- `provider.tf`: defines the AWS provider and region-level configuration
- `variables.tf`: declares shared input variables for the stack
- `terraform.tfvars`: provides environment-specific values
- `outputs.tf`: exposes useful values from the root stack
- `module-call.tf`: connects all infrastructure modules together

### Bootstrap Layer

The remote backend infrastructure is separated from the main stack so Terraform can manage its own state safely.

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

Or, in the case of the delivery module:

```text
delivery/
├── main.tf
├── output.tf
└── variables.tf
```

This structure makes the code easier to maintain, reason about, and extend. Instead of keeping all AWS resources in one large root file, each module owns a specific concern and exposes outputs that can be consumed elsewhere.

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

## Source to Deployment Flow

One of the most important parts of this project is how source code becomes a running application in AWS.

### 1. Source Commit

The workflow begins when application changes are pushed to GitHub. That push acts as the trigger for the deployment pipeline.

### 2. CodePipeline Orchestration

CodePipeline pulls the latest revision from the repository and coordinates the rest of the deployment workflow. It serves as the control plane for source, build, and deploy stages.

### 3. CodeBuild Build Stage

CodeBuild reads `buildspec.yml` and performs the build steps:
- prepares the build environment
- authenticates with Amazon ECR
- builds the Docker image for the CRM application
- tags the image appropriately
- pushes the image into the ECR repository
- packages deployment artifacts needed by CodeDeploy

This stage is where several early failures had to be corrected, including YAML syntax problems, working-directory leakage between phases, and image source issues.

### 4. Artifact and Image Delivery

After a successful build:
- the application image is stored in Amazon ECR
- deployment artifacts such as `appspec.yml` and deployment scripts are passed along for the deployment stage

This separation is important because EC2 instances do not build the app themselves. They pull a tested image and execute a controlled deployment process.

### 5. CodeDeploy on EC2

CodeDeploy targets the EC2 instances in the Auto Scaling Group and executes lifecycle hooks defined in `appspec.yml`.

Those hooks run the deployment logic in `deploy.sh`, which is responsible for:
- authenticating to ECR
- pulling the latest Docker image
- retrieving runtime secrets
- starting or replacing the running container
- validating the application health endpoint

### 6. Runtime Startup

Once the container starts, the Node.js application connects to the database and initializes runtime requirements. That includes ensuring the schema is present and the demo account is available for access.

### 7. Traffic Health Validation

The Application Load Balancer checks instance health before routing traffic. If the application is not healthy, requests do not flow to that instance. This helps protect the platform from partially failed deployments.

In practical terms, the full path looks like this:

```text
GitHub
  -> CodePipeline
    -> CodeBuild
      -> Amazon ECR
        -> CodeDeploy
          -> EC2 Auto Scaling Group
            -> Dockerized CRM Application
              -> RDS MySQL
```

---

## Application and Demo Login Flow

The demo login is useful because it shows how the deployed application behaves after the infrastructure and pipeline are working.

### Request Flow

1. A user accesses the CRM endpoint through the browser
2. Route 53 and CloudFront direct the request toward the platform
3. The Application Load Balancer forwards the request to a healthy EC2 instance
4. The Dockerized Node.js application handles the request
5. The application reads and writes data through RDS MySQL

### Demo Account Flow

The application includes a seeded demo account:

```text
Email: demo@nexuscrm.io
Password: Demo1234!
```

At startup, the application is designed to ensure that:
- the database schema exists
- required tables are initialized
- the demo account is available with a working password hash

That became an important part of the project because early deployments succeeded at the infrastructure level but still failed functionally when registration and login flows hit an uninitialized or inconsistent database state.

The final runtime behavior supports a much better deployment model:
- fresh environments can initialize correctly
- the demo account remains usable
- authentication can be validated after deployment
- the app can be tested as a working CRM, not just as a reachable endpoint

This is a good example of the difference between infrastructure health and application health. A green deployment is not enough if users still cannot log in.

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

This design avoided hardcoded secrets in the repository and ensured that secret access depended on both IAM permission and KMS decryption permission.

---

## Logging and Operational Visibility

This project required operational visibility across multiple services, not just application logs.

The main troubleshooting and validation points included:
- CodePipeline execution history for stage-level failures
- CodeBuild logs for buildspec and image build problems
- CodeDeploy lifecycle logs for deployment hook failures
- ALB target health checks for application readiness
- EC2 bootstrap behavior through user data execution
- application health endpoint validation after deployment

This mattered because many of the failures were cross-service failures. For example, a deployment could fail because the instance bootstrapped incorrectly, because a secret could not be decrypted, or because the app started without a valid schema. Getting the platform stable meant following the failure across AWS service boundaries instead of stopping at the first visible symptom.

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

The outcome was not just a working Terraform deployment, but a functioning application platform that could successfully build, deploy, start, and authenticate users.

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

What made this project meaningful was that it forced me to think like an operator, not just a builder. The most valuable work happened after the first deployment, when the system had to be traced, corrected, and stabilized until it behaved like a real usable platform.

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
