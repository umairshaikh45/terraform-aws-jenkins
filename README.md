# Terraform AWS Jenkins — ECS on EC2 with EFS, ALB, HTTPS & Terragrunt

> Deploy a production-ready **Jenkins CI/CD server on AWS ECS** using Terraform.  
> Persistent storage via EFS, optional Application Load Balancer with HTTPS, automated S3 backups, CloudWatch logging, and full Terragrunt support.

[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.5-purple?logo=terraform)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-ECS%20%7C%20EFS%20%7C%20ALB-orange?logo=amazonaws)](https://aws.amazon.com/)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue)](LICENSE)
[![Registry](https://img.shields.io/badge/Terraform%20Registry-umairshaikh45%2Fjenkins%2Faws-blueviolet)](https://registry.terraform.io/modules/umairshaikh45/jenkins/aws)

---

## Overview

This Terraform module provisions a **fully containerized Jenkins server on Amazon ECS (EC2 launch type)**.  
Jenkins runs as a Docker container with its home directory persisted on Amazon EFS — so jobs survive container restarts.  
An optional Application Load Balancer (ALB) puts Jenkins behind HTTPS with automatic HTTP-to-HTTPS redirect.

**Use cases:**
- Self-hosted Jenkins CI/CD on AWS infrastructure
- Jenkins master running on ECS with EFS-backed persistent storage
- Jenkins behind an ALB with ACM-managed TLS certificates
- Automated EFS-to-S3 backups via AWS DataSync
- Jenkins plugin management via Terraform

---

## Architecture

```
Internet → ALB (HTTP/HTTPS) → EC2 (Auto Scaling Group) → ECS Cluster → Jenkins Container
                                                                               |
                                                                         EFS (jenkins_home)
                                                                               |
                                                                     S3 Backup (DataSync)
```

![Jenkins ECS Architecture](https://raw.githubusercontent.com/umairshaikh45/terraform-aws-jenkins/Master/images/Diagram.png)

---

## Features

- **ECS on EC2** — Jenkins runs as an ECS task on EC2 instances managed by an Auto Scaling Group
- **EFS Persistence** — Jenkins home directory is mounted from EFS; no data loss on task restart
- **ALB with HTTPS** — Optional ALB with ACM certificate support and HTTP-to-HTTPS redirect
- **S3 Backup** — Scheduled EFS-to-S3 backup via AWS DataSync (configurable cron)
- **CloudWatch Logging** — Container logs streamed to CloudWatch with configurable retention
- **Plugin Management** — Automatic Jenkins plugin updates on `terraform apply`
- **Spot + On-Demand Mix** — ASG supports mixed instance policies for cost optimization
- **Terragrunt Ready** — Includes `live/prod/jenkins/` example for Terragrunt deployments
- **Security Groups** — Pre-configured groups for Jenkins UI, JNLP agents, EFS, and ALB

---

## Prerequisites

- Terraform >= 1.5
- AWS CLI configured with appropriate IAM permissions
- An existing VPC with subnets
- Java (only required when `enable_update_plugins = true`)

---

## Usage

### Basic — Jenkins with ALB (HTTP)

```hcl
module "jenkins" {
  source  = "umairshaikh45/jenkins/aws"
  version = "~> 1.0"

  vpc_id = "vpc-12345678"

  instance_type        = "t3.medium"
  min_instance_size    = 1
  max_instance_size    = 2
  on_demand_percentage = 100

  cpu    = 1024
  memory = 2048

  create_alb = true

  jenkins_environment_variables = {
    JAVA_OPTS                = "-Djenkins.install.runSetupWizard=false -Xmx1536m"
    JENKINS_SLAVE_AGENT_PORT = "8090"
    TRY_UPGRADE_IF_NO_MARKER = "true"
    JENKINS_URL              = "http://<your-alb-dns-name>/"
  }
}

output "jenkins_url" {
  value = module.jenkins.jenkins_url
}
```

### ALB with HTTPS (ACM Certificate)

```hcl
module "jenkins" {
  source  = "umairshaikh45/jenkins/aws"
  version = "~> 1.0"

  vpc_id = "vpc-12345678"

  instance_type = "t3.medium"
  cpu           = 1024
  memory        = 2048

  create_alb      = true
  certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

  jenkins_environment_variables = {
    JAVA_OPTS                = "-Djenkins.install.runSetupWizard=false -Xmx1536m"
    JENKINS_SLAVE_AGENT_PORT = "8090"
    TRY_UPGRADE_IF_NO_MARKER = "true"
    JENKINS_URL              = "https://jenkins.example.com/"
  }
}
```

### With EFS Backup to S3

```hcl
module "jenkins" {
  source  = "umairshaikh45/jenkins/aws"
  version = "~> 1.0"

  vpc_id     = "vpc-12345678"
  create_alb = true

  enable_backup   = true
  backup_schedule = "cron(0 6 ? * MON-FRI *)"
  force_delete_s3 = false
}

output "backup_bucket" {
  value = module.jenkins.backup_s3_bucket
}
```

### Custom Security Groups

```hcl
module "jenkins" {
  source  = "umairshaikh45/jenkins/aws"
  version = "~> 1.0"

  vpc_id = "vpc-12345678"

  additional_security_groups = [
    {
      name = "custom-sg"
      ingress_rules = [
        {
          from_port   = 80
          to_port     = 80
          protocol    = "tcp"
          cidr_blocks = ["0.0.0.0/0"]
          description = "Allow HTTP traffic"
        }
      ]
      egress_rules = [
        {
          from_port   = 0
          to_port     = 0
          protocol    = "-1"
          cidr_blocks = ["0.0.0.0/0"]
          description = "Allow all egress"
        }
      ]
      tags = { Name = "custom-sg" }
    }
  ]
}
```

---

## Jenkins Configuration

### Running Jobs on Agent Nodes

By default, all Jenkins jobs run on the master node. To provision dynamic ECS-based agent nodes:

1. Install the [Amazon ECS / Fargate plugin](https://plugins.jenkins.io/amazon-ecs/) in Jenkins
2. Go to **Manage Jenkins → Clouds → New Cloud**
3. Configure the ECS cluster and task definition for agent containers

### Accessing Jenkins Without DNS

1. Open the AWS Console → **ECS** → select the `jenkins` cluster
2. Find the running task → **Networking** tab
3. Copy the EC2 instance Public IP and open `http://<Public-IP>:8080`

### Automatic Plugin Updates

Set `enable_update_plugins = true` to run the plugin update script on every `terraform apply`.
Requires Java installed on the machine running Terraform, and `JENKINS_URL` must point to a live Jenkins instance.

---

## Inputs

| Name | Description | Default | Required |
|------|-------------|---------|:--------:|
| `vpc_id` | VPC ID to deploy all resources into | — | Yes |
| `region` | AWS region for all resources | `"us-east-1"` | No |
| `instance_type` | EC2 instance type for ECS container instances | `"t3.medium"` | No |
| `min_instance_size` | Minimum EC2 instances in the Auto Scaling Group | `1` | No |
| `max_instance_size` | Maximum EC2 instances in the Auto Scaling Group | `1` | No |
| `on_demand_percentage` | Percentage of on-demand instances; lower values add Spot | `100` | No |
| `ami_id` | Custom ECS-optimized AMI ID; empty = latest AL2 via SSM | `""` | No |
| `desired_service_count` | Desired number of running ECS tasks | `1` | No |
| `cpu` | CPU units for the Jenkins container (1024 = 1 vCPU) | `500` | No |
| `memory` | Memory (MiB) for the Jenkins container | `1024` | No |
| `jenkins_image` | Jenkins Docker image to run | `"jenkins/jenkins:lts"` | No |
| `jenkins_environment_variables` | Environment variables injected into the Jenkins container | See variable.tf | No |
| `enable_update_plugins` | Run plugin update script after deploy; requires Java | `false` | No |
| `create_alb` | Create an Application Load Balancer in front of Jenkins | `false` | No |
| `certificate_arn` | ACM certificate ARN for HTTPS; enables HTTP-to-HTTPS redirect | `""` | No |
| `alb_internal` | Create an internal (non-internet-facing) ALB | `false` | No |
| `alb_deletion_protection` | Enable ALB deletion protection | `false` | No |
| `cloudwatch_name` | CloudWatch Log Group name for Jenkins logs | `"/Jenkins"` | No |
| `retention_in_days` | CloudWatch log retention period in days | `30` | No |
| `efs_creation_token` | Unique creation token for the EFS filesystem | `"jenkins_efs"` | No |
| `efs_performance_mode` | EFS performance mode: `generalPurpose` or `maxIO` | `"generalPurpose"` | No |
| `efs_throughput_mode` | EFS throughput mode: `bursting` or `provisioned` | `"bursting"` | No |
| `enable_backup` | Enable EFS-to-S3 backup via AWS DataSync | `false` | No |
| `backup_schedule` | Cron expression for the DataSync backup task | `"cron(0 6 ? * MON-FRI *)"` | No |
| `force_delete_s3` | Destroy backup S3 bucket even when it contains objects | `false` | No |
| `security_groups` | Security group configs; `cidr_blocks = []` falls back to VPC subnet CIDRs | See variable.tf | No |
| `additional_security_groups` | Extra security group configs merged alongside the defaults | `[]` | No |

---

## Outputs

| Name | Description |
|------|-------------|
| `security_group_ids` | Map of security group name to ID for all managed security groups |
| `ecs_cluster_name` | Name of the Jenkins ECS cluster |
| `ecs_cluster_arn` | ARN of the Jenkins ECS cluster |
| `efs_id` | EFS filesystem ID used for `jenkins_home` persistence |
| `cloudwatch_log_group_name` | CloudWatch log group name for Jenkins container logs |
| `alb_dns_name` | ALB DNS name; `null` when `create_alb = false` |
| `alb_arn` | ALB ARN; `null` when `create_alb = false` |
| `jenkins_url` | Jenkins access URL (HTTP or HTTPS depending on `certificate_arn`) |
| `backup_s3_bucket` | S3 bucket name for EFS backups; `null` when `enable_backup = false` |

---

## Resources Created

| Resource | Type |
|----------|------|
| `aws_ecs_cluster` | Resource |
| `aws_ecs_service` | Resource |
| `aws_ecs_task_definition` | Resource |
| `aws_ecs_capacity_provider` | Resource |
| `aws_ecs_cluster_capacity_providers` | Resource |
| `aws_autoscaling_group` | Resource |
| `aws_launch_template` | Resource |
| `aws_efs_file_system` | Resource |
| `aws_efs_mount_target` | Resource |
| `aws_lb` | Resource |
| `aws_lb_target_group` | Resource |
| `aws_lb_listener` | Resource |
| `aws_security_group` | Resource |
| `aws_iam_role` | Resource |
| `aws_iam_role_policy_attachment` | Resource |
| `aws_iam_instance_profile` | Resource |
| `aws_cloudwatch_log_group` | Resource |
| `aws_s3_bucket` | Resource |
| `null_resource` | Resource |
| `random_id` | Resource |
| `aws_region` | Data |
| `aws_subnets` | Data |
| `aws_subnet` | Data |
| `aws_vpc` | Data |
| `aws_ssm_parameter` | Data |
| `aws_iam_policy_document` | Data |
| `aws_iam_policy` | Data |

---

## Modules

| Name | Purpose |
|------|---------|
| `backup_tasks` | DataSync task: syncs EFS to S3 on a schedule |
| `efs_location` | DataSync EFS source location |
| `s3_location` | DataSync S3 destination location |

---

## Related Projects

- [terraform-aws-jenkins-eks](https://github.com/umairshaikh45/terraform-aws-jenkins-eks) — Run Jenkins on Amazon EKS (Kubernetes) instead of ECS

---

## Maintainer

Maintained by [Umair Shaikh](https://github.com/umairshaikh45/).

---

## License

Apache 2.0. See [LICENSE](https://github.com/umairshaikh45/terraform-aws-jenkins/blob/Master/LICENSE) for full details.

---

## Keywords

`terraform` `aws` `jenkins` `ecs` `ec2` `efs` `alb` `ci-cd` `continuous-integration` `devops`
`infrastructure-as-code` `iac` `jenkins-on-aws` `jenkins-ecs` `jenkins-docker` `jenkins-terraform`
`aws-ecs` `aws-efs` `aws-alb` `terragrunt` `cloudwatch` `datasync` `s3-backup` `auto-scaling`
`jenkins-master` `jenkins-ci` `jenkins-server` `aws-infrastructure` `terraform-module`
