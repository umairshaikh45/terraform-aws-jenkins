
variable "region" {
  description = "AWS region for all resources."
  type        = string
  default     = "us-east-1"
}

variable "ami_id" {
  description = "ECS-optimized AMI ID. Defaults to the latest Amazon Linux 2 ECS-optimized AMI via SSM."
  type        = string
  default     = ""
}

variable "enable_update_plugins" {
  description = "Run the Jenkins plugin update script on the Terraform host after deployment. Requires Java."
  type        = bool
  default     = false
}

variable "min_instance_size" {
  description = "Minimum number of EC2 instances in the ASG."
  type        = number
  default     = 1
}

variable "desired_service_count" {
  description = "Desired number of running ECS tasks."
  type        = number
  default     = 1
}

variable "max_instance_size" {
  description = "Maximum number of EC2 instances in the ASG."
  type        = number
  default     = 1
}

variable "on_demand_percentage" {
  description = "Percentage of on-demand instances above the on-demand base. Defaults to 100 (all on-demand). Lower values enable Spot for cost savings but risk interruptions."
  type        = number
  default     = 100
}

variable "instance_type" {
  description = "EC2 instance type for ECS container instances."
  type        = string
  default     = "t3.medium"
}

variable "vpc_id" {
  description = "VPC ID where all resources will be created."
  type        = string
}

variable "jenkins_image" {
  description = "Jenkins Docker image. Digest-pinned at plan time."
  default     = "jenkins/jenkins:lts"
}

variable "cloudwatch_name" {
  description = "Name of the CloudWatch Log Group."
  type        = string
  default     = "/Jenkins"
}

variable "efs_creation_token" {
  description = "Unique creation token for the EFS filesystem."
  type        = string
  default     = "jenkins_efs"
}

variable "efs_performance_mode" {
  description = "EFS performance mode: generalPurpose or maxIO."
  type        = string
  default     = "generalPurpose"
}

variable "efs_throughput_mode" {
  description = "EFS throughput mode: bursting or provisioned."
  type        = string
  default     = "bursting"
}

variable "retention_in_days" {
  description = "CloudWatch log retention in days."
  type        = number
  default     = 30
}

variable "cpu" {
  description = "CPU units reserved for the Jenkins container."
  type        = number
  default     = 500
}

variable "memory" {
  description = "Memory (MiB) reserved for the Jenkins container."
  type        = number
  default     = 1024
}

variable "backup_schedule" {
  description = "Cron expression for the EFS-to-S3 DataSync backup task."
  type        = string
  default     = "cron(0 6 ? * MON-FRI *)"
}

variable "enable_backup" {
  description = "Enable EFS backup to S3 via DataSync."
  type        = bool
  default     = false
}

variable "force_delete_s3" {
  description = "Allow Terraform to destroy the backup S3 bucket even when it contains objects. Keep false in production."
  type        = bool
  default     = false
}

variable "create_alb" {
  description = "Create an Application Load Balancer in front of Jenkins."
  type        = bool
  default     = false
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS on the ALB. When provided, HTTP redirects to HTTPS automatically."
  type        = string
  default     = ""
}

variable "alb_internal" {
  description = "Create an internal (non-internet-facing) ALB."
  type        = bool
  default     = false
}

variable "alb_deletion_protection" {
  description = "Enable deletion protection on the ALB to prevent accidental destruction."
  type        = bool
  default     = false
}

variable "jenkins_environment_variables" {
  description = "Map of environment variables injected into the Jenkins ECS container."
  type        = map(string)
  default = {
    JAVA_OPTS                = "-Djenkins.install.runSetupWizard=false"
    JENKINS_SLAVE_AGENT_PORT = "8090"
    TRY_UPGRADE_IF_NO_MARKER = "true"
    JENKINS_URL              = "http://localhost:8080/"
  }
}

variable "security_groups" {
  description = "Security group configurations attached to Jenkins instances. cidr_blocks = [] falls back to VPC subnet CIDRs."
  type = list(object({
    name = string
    ingress_rules = list(object({
      from_port   = number
      to_port     = number
      protocol    = string
      cidr_blocks = list(string)
      self        = optional(bool)
      description = string
    }))
    egress_rules = list(object({
      from_port   = number
      to_port     = number
      protocol    = string
      cidr_blocks = list(string)
      self        = optional(bool)
      description = string
    }))
    tags = map(string)
  }))
  default = [
    {
      name = "jenkins-ingress"
      ingress_rules = [
        {
          from_port   = 8080
          to_port     = 8080
          protocol    = "tcp"
          cidr_blocks = []
          description = "Jenkins UI -VPC only. Use create_alb=true for public access."
        },
        {
          from_port   = 8090
          to_port     = 8090
          protocol    = "tcp"
          cidr_blocks = []
          description = "JNLP agent port -VPC only"
        }
      ]
      egress_rules = []
      tags = {
        Name = "Jenkins-sg-ingress"
      }
    },
    {
      name          = "jenkins-egress"
      ingress_rules = []
      egress_rules = [
        {
          from_port   = 443
          to_port     = 443
          protocol    = "tcp"
          cidr_blocks = ["0.0.0.0/0"]
          description = "HTTPS outbound -ECR, ECS agent, SSM, CloudWatch"
        },
        {
          from_port   = 2049
          to_port     = 2049
          protocol    = "tcp"
          cidr_blocks = []
          description = "EFS NFS outbound"
        },
        {
          from_port   = 8080
          to_port     = 8080
          protocol    = "tcp"
          cidr_blocks = []
          description = "Internal HTTP"
        },
        {
          from_port   = 8090
          to_port     = 8090
          protocol    = "tcp"
          cidr_blocks = []
          description = "JNLP agent outbound"
        }
      ]
      tags = {
        Name = "Jenkins-sg-egress"
      }
    },
    {
      name = "jenkins-efs"
      ingress_rules = [
        {
          from_port   = 2049
          to_port     = 2049
          protocol    = "tcp"
          cidr_blocks = []
          description = "NFS from VPC subnets"
        }
      ]
      egress_rules = []
      tags = {
        Name = "Jenkins-sg-efs"
      }
    },
    {
      name = "jenkins-agent"
      ingress_rules = [
        {
          from_port   = 0
          to_port     = 0
          protocol    = "-1"
          self        = true
          cidr_blocks = []
          description = "All traffic from same SG -agent communication"
        }
      ]
      egress_rules = [
        {
          from_port   = 0
          to_port     = 0
          protocol    = "-1"
          self        = true
          cidr_blocks = []
          description = "All traffic to same SG -agent communication"
        }
      ]
      tags = {
        Name = "Jenkins-sg-agent"
      }
    }
  ]
}

variable "subnet_ids" {
  description = "Explicit subnet IDs for EFS mount targets and the ASG. When provided, auto-discovery of subnets from vpc_id is skipped and az_count is ignored."
  type        = list(string)
  default     = []
}

variable "az_count" {
  description = "Number of Availability Zones to use. When null (default), all subnets found in the VPC are used. Ignored when subnet_ids is set."
  type        = number
  default     = null

  validation {
    condition     = var.az_count == null || (var.az_count >= 1 && var.az_count <= 6)
    error_message = "az_count must be between 1 and 6, or null to use all available AZs."
  }
}

variable "additional_security_groups" {
  description = "Additional security group configurations merged with the defaults."
  type = list(object({
    name = string
    ingress_rules = list(object({
      from_port   = number
      to_port     = number
      protocol    = string
      cidr_blocks = list(string)
      self        = optional(bool)
      description = string
    }))
    egress_rules = list(object({
      from_port   = number
      to_port     = number
      protocol    = string
      cidr_blocks = list(string)
      self        = optional(bool)
      description = string
    }))
    tags = map(string)
  }))
  default = []
}
