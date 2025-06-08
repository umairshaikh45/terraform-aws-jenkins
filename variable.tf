
variable "region" {
  description = "Region of the deployment"
  type        = string
  default = "us-east-1"
}
variable "ami_id" {
  description = "ECS optamized ami"
  type        = string
  default = ""
}
variable "enable_update_plugins" {
  type    = bool
  default = false
}
variable "min_instance_size" {
  description = "Minimum number of EC2 instances."
  type        = number
  default     = 1
}
variable "desired_service_count" {
  description = "Desired number of ECS services."
  type        = number
  default     = 1
}
variable "max_instance_size" {
  description = "Maximum number of EC2 instances."
  type        = number
  default     = 1
}
variable "instance_type" {
  description = "Type of ec2 instance"
  type        = string
  default     = "t2.medium"
}
variable "vpc_id" {
  description = "Vpc id to be used for all the resources"
  type        = string
}
variable "cloudwatch_environment" {
  description = "Environment for the cloud watch"
  default     = "Sandbox"
}
variable "jenkins_image" {
  description = "Which jenkins image to be used for the master."
  default     = "jenkins/jenkins:lts"
}
variable "cloudwatch_name" {
  description = "The name of the CloudWatch Log Group"
  type        = string
  default     = "/Jenkins"
}
variable "efs_creation_token" {
  description = "EFS: name of the efs filesystem"
  type        = string
  default     = "jenkins_efs"
}
variable "efs_performance_mode" {
  description = "EFS: performance mode for efs"
  type        = string
  default     = "generalPurpose"
}

variable "efs_throughput_mode" {
  description = "EFS: throughput mode"
  type        = string
  default     = "bursting"
}
variable "retention_in_days" {
  description = "The number of days to retain logs"
  type        = number
  default     = 7
}
variable "jenkins_slave_agent_port" {
  description = "Environment port configuration for slave"
  type        = string
  default     = "8090"
}
variable "cpu" {
  description = "Amount of cpu to be use in docker for jenkins"
  type        = number
  default     = 500
}
variable "memory" {
  description = "Amount of memory to be use in docker for jenkins"
  type        = number
  default     = 1024
}

variable "jenkins_url" {
  description = "Jenkins url configuration"
  type        = string
  default     = "http://localhost:8080/"
}
variable "security_groups" {
  description = "List of security group configurations"
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
          from_port   = 443
          to_port     = 443
          protocol    = "tcp"
          cidr_blocks = ["182.199.108.0/22", "140.82.112.0/20", "192.30.240.0/20"]
          description = "Github"
        },
        {
          from_port   = 8080
          to_port     = 8080
          protocol    = "tcp"
          cidr_blocks = ["0.0.0.0/0"]
          description = "HTTP access for internal Jenkins communication"
        },
        {
          from_port   = 8090
          to_port     = 8090
          protocol    = "tcp"
          cidr_blocks = []
          description = "JNLP from workers"
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
          description = "ECS agent registration"
        },
        {
          from_port   = 2049
          to_port     = 2049
          protocol    = "tcp"
          cidr_blocks = []
          description = "EFS access"
        },
        {
          from_port   = 8080
          to_port     = 8080
          protocol    = "tcp"
          cidr_blocks = []
          description = "Internal HTTP access"
        },
        {
          from_port   = 8090
          to_port     = 8090
          protocol    = "tcp"
          cidr_blocks = []
          description = "JNLP to connect workers"
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
          description = "EFS inbound"
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
          description = "Agent inbound"
        }
      ]
      egress_rules = [
        {
          from_port   = 0
          to_port     = 0
          protocol    = "-1"
          self        = true
          cidr_blocks = []
          description = "Agent outbound"
        }
      ]
      tags = {
        Name = "Jenkins-sg-agent"
      }
    }
  ]
}
variable "additional_security_groups" {
  description = "Optional additional security group configurations."
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
variable "backup_enabled" {
  description = "Whether to enable Jenkins backup to S3"
  type        = bool
  default     = false
}

variable "backup_bucket_name" {
  description = "S3 bucket name for Jenkins backups"
  type        = string
  default     = ""
}

variable "backup_schedule" {
  description = "Cron expression for backup job"
  type        = string
  default     = "0 3 * * *"
}
