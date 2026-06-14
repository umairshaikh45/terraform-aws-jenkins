<!-- @format -->

# Jenkins on AWS ECS Using Terraform (Highly Available Setup)

This Terraform module sets up a robust Jenkins infrastructure in AWS, including security groups, ECS task definitions, EFS for persistent storage, and other supporting components. It is designed to be flexible, allowing users to override defaults and customize the deployment while providing sensible defaults for common use cases.

---

## Why Use This Module?

Managing Jenkins on AWS can be complex — this module simplifies it with:

- A fully containerized setup on ECS
- Persistent and shareable EFS storage
- Automated backup to S3 using DataSync
- CloudWatch-based centralized logging
- Automatic Jenkins plugin management
- Complete customization via Terraform variables

**Whether you're setting up a small CI/CD instance or scaling Jenkins in production, this module gives you flexibility and infrastructure as code.**

## What's Included

| Component             | Purpose                                 |
|-----------------------|-----------------------------------------|
| ECS Cluster           | Hosts the Jenkins container             |
| ECS Task Definition   | Defines Jenkins container config        |
| EFS File System       | Persistent Jenkins home directory       |
| ALB (optional)        | Public-facing load balancer for Jenkins |
| CloudWatch Logs       | Streams container logs                  |
| S3 + DataSync         | Optional backup of Jenkins data         |
| IAM Roles             | Secure access to AWS services           |
| Security Groups       | VPC traffic rules for Jenkins           |

## Key Features of This Jenkins on ECS Module

- **Jenkins Deployment:**
  - Deploy Jenkins as a containerized service on ECS.
  - Configure Jenkins with customizable plugins.
  - Always get the latest version of Jenkins.
  - Plugins are automatically updated during `terraform apply` if `enable_update_plugins` is set to `true`.

- **Networking:**
  - Predefined security groups for ingress/egress rules.
  - Support for adding additional security groups.
  - Allows traffic to flow within your VPC based on CIDR subnet configuration.

- **Persistent Storage:**
  - Automatically provisions an EFS file system for Jenkins data.
  - If the master container goes down, ECS will automatically bring up another container, and jobs will resume from the point where Jenkins went down.

- **CloudWatch Integration:**
  - Logs are forwarded to CloudWatch with customizable retention periods.

- **Customization:**
  - All major settings, such as instance sizes, security rules, and Jenkins configurations, can be overridden.

- **Backup:**
  - Backup Jenkins data from EFS to S3 using AWS DataSync, scheduled with a configurable cron expression.

---
## Automatic Jenkins Plugin Updates
 - In order for automatic plugins update to work need to set `enable_update_plugins` to `true` by default it is set to `false`.
 - The Jenkins should be reachable using your own DNS to resolve `jenkins_url` if using Loadbalancer its target group should point to the instance running on ECS cluster.

---

## Prerequisites
- Terraform >= 1.3
- AWS CLI configured with appropriate permissions
- Java runtime (only required when `enable_update_plugins = true`)

## Jenkins Configuration Tips

- **Job Execution on Master and Slaves:**
  - By default, all Jenkins jobs will run on the Master node. To enable jobs to run on dynamically provisioned slaves, you need to download and configure the **Amazon Elastic Container Service (ECS) / Fargate** [Amazon Elastic Container Service (ECS) / Fargate)](https://plugins.jenkins.io/amazon-ecs/) on Jenkins.
  - After installing the plugin, navigate to `Manage Jenkins` and select the `Clouds` section.
  - Create a new cloud configuration and set it up according to your requirements.


- **Accessing Jenkins Without DNS:**
  - If you do not have a DNS configured, you can access Jenkins manually:
    1. Log in to the AWS Management Console.
    2. Navigate to the **ECS** section and locate the `jenkins` cluster.
    3. Select the running task and go to the **Networking** tab.
    4. Click on the **Public IP** of the associated EC2 instance and append port `8080` to the URL (e.g., `http://<Public-IP>:8080`).

---
# Resources

| Category                               | Type     |
|----------------------------------------|----------|
| aws_security_group                     | Resource |
| null_resource                          | Resource |
| aws_iam_role                           | Resource |
| aws_iam_role_policy_attachment         | Resource |
| aws_iam_instance_profile               | Resource |
| aws_efs_file_system                    | Resource |
| aws_efs_mount_target                   | Resource |
| aws_ecs_task_definition                | Resource |
| aws_ecs_service                        | Resource |
| aws_ecs_cluster                        | Resource |
| aws_ecs_cluster_capacity_providers     | Resource |
| aws_ecs_capacity_provider              | Resource |
| aws_autoscaling_group                  | Resource |
| aws_launch_template                    | Resource |
| aws_cloudwatch_log_group               | Resource |
| aws_lb                                 | Resource |
| aws_lb_target_group                    | Resource |
| aws_lb_listener                        | Resource |
| aws_s3_bucket                          | Resource |
| random_id                              | Resource |
| aws_region                             | Data     |
| aws_subnets                            | Data     |
| aws_subnet                             | Data     |
| aws_vpc                                | Data     |
| aws_ssm_parameter                      | Data     |
| aws_iam_policy_document                | Data     |
| aws_iam_policy                         | Data     |


# Modules

| Module Name     | Purpose                                          |
|-----------------|--------------------------------------------------|
| `backup_tasks`  | Handles DataSync job setup for EFS to S3 backups |
| `efs_location`  | Creates the EFS location needed for DataSync     |
| `s3_location`   | Configures the S3 location for backup            |

# Input

| Name                            | Description                                                                                      | Type                  | Default                        | Required |
|---------------------------------|--------------------------------------------------------------------------------------------------|-----------------------|--------------------------------|----------|
| `vpc_id`                        | The ID of the VPC to deploy resources into.                                                      | `string`              | —                              | **Yes**  |
| `region`                        | AWS region for the deployment.                                                                   | `string`              | `"us-east-1"`                  | No       |
| `instance_type`                 | EC2 instance type for ECS container instances.                                                   | `string`              | `"t3.medium"`                  | No       |
| `min_instance_size`             | Minimum number of EC2 instances in the ASG.                                                      | `number`              | `1`                            | No       |
| `max_instance_size`             | Maximum number of EC2 instances in the ASG.                                                      | `number`              | `1`                            | No       |
| `on_demand_percentage`          | Percentage of on-demand instances above the base. `100` = all on-demand; lower values use Spot.  | `number`              | `100`                          | No       |
| `ami_id`                        | Custom ECS-optimized AMI ID. Leave empty to use the latest Amazon Linux 2 ECS AMI via SSM.       | `string`              | `""`                           | No       |
| `desired_service_count`         | Desired number of running ECS tasks.                                                             | `number`              | `1`                            | No       |
| `cpu`                           | CPU units reserved for the Jenkins container (1024 = 1 vCPU).                                   | `number`              | `500`                          | No       |
| `memory`                        | Memory (MiB) reserved for the Jenkins container.                                                 | `number`              | `1024`                         | No       |
| `jenkins_image`                 | Jenkins Docker image.                                                                            | `string`              | `"jenkins/jenkins:lts"`        | No       |
| `jenkins_environment_variables` | Map of environment variables injected into the Jenkins ECS container.                            | `map(string)`         | See example below              | No       |
| `enable_update_plugins`         | Run the Jenkins plugin update script after deployment. Requires Java on the Terraform host.      | `bool`                | `false`                        | No       |
| `create_alb`                    | Create an Application Load Balancer in front of Jenkins.                                         | `bool`                | `false`                        | No       |
| `certificate_arn`               | ACM certificate ARN for HTTPS. When set, HTTP automatically redirects to HTTPS.                  | `string`              | `""`                           | No       |
| `alb_internal`                  | Create an internal (non-internet-facing) ALB.                                                    | `bool`                | `false`                        | No       |
| `alb_deletion_protection`       | Enable ALB deletion protection to prevent accidental destruction.                                | `bool`                | `false`                        | No       |
| `cloudwatch_name`               | CloudWatch log group name for Jenkins logs.                                                      | `string`              | `"/Jenkins"`                   | No       |
| `retention_in_days`             | Number of days to retain CloudWatch logs.                                                        | `number`              | `30`                           | No       |
| `efs_creation_token`            | Unique creation token for the EFS filesystem.                                                    | `string`              | `"jenkins_efs"`                | No       |
| `efs_performance_mode`          | EFS performance mode: `generalPurpose` or `maxIO`.                                               | `string`              | `"generalPurpose"`             | No       |
| `efs_throughput_mode`           | EFS throughput mode: `bursting` or `provisioned`.                                                | `string`              | `"bursting"`                   | No       |
| `enable_backup`                 | Enable EFS backup to S3 via DataSync.                                                            | `bool`                | `false`                        | No       |
| `backup_schedule`               | Cron expression for the EFS-to-S3 DataSync backup task.                                          | `string`              | `"cron(0 6 ? * MON-FRI *)"`    | No       |
| `force_delete_s3`               | Allow Terraform to destroy the backup S3 bucket even when it contains objects.                   | `bool`                | `false`                        | No       |
| `security_groups`               | Security group configurations attached to Jenkins instances. `cidr_blocks = []` falls back to VPC subnet CIDRs. | `list(object({...}))` | See default SGs below | No       |
| `additional_security_groups`    | Extra security groups merged alongside the defaults. Use this to add rules without replacing the full list. | `list(object({...}))` | `[]`              | No       |


# Output

| Name                       | Description                                                         |
|----------------------------|---------------------------------------------------------------------|
| `security_group_ids`       | Map of security group name to ID for all managed SGs.              |
| `ecs_cluster_name`         | Name of the Jenkins ECS cluster.                                    |
| `ecs_cluster_arn`          | ARN of the Jenkins ECS cluster.                                     |
| `efs_id`                   | ID of the EFS filesystem used for `jenkins_home` persistence.       |
| `cloudwatch_log_group_name`| CloudWatch log group name for Jenkins container logs.               |
| `alb_dns_name`             | DNS name of the ALB. `null` when `create_alb = false`.              |
| `alb_arn`                  | ARN of the ALB. `null` when `create_alb = false`.                   |
| `jenkins_url`              | Jenkins access URL (HTTP or HTTPS depending on `certificate_arn`).  |
| `backup_s3_bucket`         | S3 bucket name used for EFS backups. `null` when `enable_backup = false`. |

---


# How to Use This Terraform Module for Jenkins on AWS

### Example

<details>
  <summary><strong>🔧 Basic — Jenkins with ALB (HTTP)</strong></summary>

```hcl
module "jenkins" {
  source = "umairshaikh45/jenkins/aws"

  vpc_id = "vpc-12345678"

  # Compute
  instance_type        = "t3.medium"
  min_instance_size    = 1
  max_instance_size    = 2
  on_demand_percentage = 100  # set lower (e.g. 50) to mix in Spot instances

  # ECS task
  cpu    = 1024
  memory = 2048

  # ALB — exposes Jenkins publicly on port 80
  create_alb = true

  # Jenkins container
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
</details>

<details>
  <summary><strong>🔒 ALB with HTTPS (ACM certificate)</strong></summary>

```hcl
module "jenkins" {
  source = "umairshaikh45/jenkins/aws"

  vpc_id = "vpc-12345678"

  instance_type = "t3.medium"
  cpu           = 1024
  memory        = 2048

  # ALB with TLS — HTTP automatically redirects to HTTPS
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
</details>

<details>
  <summary><strong>💾 With EFS backup to S3</strong></summary>

```hcl
module "jenkins" {
  source = "umairshaikh45/jenkins/aws"

  vpc_id = "vpc-12345678"

  create_alb = true

  # Backup Jenkins home to S3 every weekday at 06:00 UTC
  enable_backup   = true
  backup_schedule = "cron(0 6 ? * MON-FRI *)"
  force_delete_s3 = false  # keep backups even after terraform destroy
}

output "backup_bucket" {
  value = module.jenkins.backup_s3_bucket
}
```
</details>

<details>
  <summary><strong>🔧 Custom security groups</strong></summary>

```hcl
module "jenkins" {
  source = "umairshaikh45/jenkins/aws"

  vpc_id = "vpc-12345678"

  # Add rules on top of the built-in defaults without replacing them
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
      tags = {
        Name = "custom-sg"
      }
    }
  ]
}
```
</details>

## Maintainer

Module is maintained by [Umair Shaikh](https://github.com/umairshaikh45/).

## License: Apache 2.0

Apache 2 Licensed. See [LICENSE](https://github.com/umairshaikh45/terraform-aws-jenkins/blob/Master/LICENSE) for full details.

## Jenkins on ECS Architecture Diagram

![Jenkins ECS Architecture](https://raw.githubusercontent.com/umairshaikh45/terraform-aws-jenkins/Master/images/Diagram.png)
