# Production Jenkins deployment
#
# Usage:
#   cd live/prod/jenkins
#   terragrunt init
#   terragrunt plan
#   terragrunt apply

include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../"
}

inputs = {

  # ---------------------------------------------------------------------------
  # Core
  # ---------------------------------------------------------------------------
  region = "us-east-1"
  vpc_id = "vpc-xxxxxxxxxxxx"

  # ---------------------------------------------------------------------------
  # Compute
  # ---------------------------------------------------------------------------
  instance_type        = "t3.medium"
  min_instance_size    = 1
  max_instance_size    = 2
  on_demand_percentage = 100   # 100 = all on-demand (safe for master). Lower for spot savings.

  # Custom AMI ID -leave empty to use the latest ECS-optimised Amazon Linux 2 AMI via SSM
  ami_id = ""

  # ---------------------------------------------------------------------------
  # ECS task
  # ---------------------------------------------------------------------------
  desired_service_count = 1
  cpu                   = 1024  # CPU units (1024 = 1 vCPU)
  memory                = 2048  # MiB

  # ---------------------------------------------------------------------------
  # ALB + TLS
  # create_alb = true puts an ALB in front of Jenkins (recommended).
  # Set certificate_arn to an ACM cert ARN to enable HTTPS + HTTP→HTTPS redirect.
  # Leave certificate_arn = "" to serve plain HTTP on port 80.
  # ---------------------------------------------------------------------------
  create_alb              = true
  certificate_arn         = ""     # e.g. arn:aws:acm:us-east-1:123456789012:certificate/...
  alb_internal            = false  # true = private ALB (only reachable within VPC)
  alb_deletion_protection = false  # set to true in production once stable, to guard against accidental destroy

  # ---------------------------------------------------------------------------
  # ECS agent -Jenkins plugin updater
  # Requires Java on the machine running terragrunt apply and a live JENKINS_URL
  # ---------------------------------------------------------------------------
  enable_update_plugins = false  # Set to true only after Jenkins is live and JENKINS_URL below points to the real ALB DNS name

  # ---------------------------------------------------------------------------
  # Jenkins container
  # ---------------------------------------------------------------------------
  jenkins_image = "jenkins/jenkins:lts"

  jenkins_environment_variables = {
    JAVA_OPTS                = "-Djenkins.install.runSetupWizard=false -Xmx1536m"
    JENKINS_SLAVE_AGENT_PORT = "8090"
    TRY_UPGRADE_IF_NO_MARKER = "true"
    JENKINS_URL              = "http://localhost:8080/"  # TODO: replace with ALB DNS after first apply, e.g. http://<alb-dns-name>/
  }

  # ---------------------------------------------------------------------------
  # EFS (persistent Jenkins home)
  # ---------------------------------------------------------------------------
  efs_creation_token   = "jenkins-efs-prod"
  efs_performance_mode = "generalPurpose"  # or "maxIO" for very high parallelism
  efs_throughput_mode  = "bursting"        # or "provisioned"

  # ---------------------------------------------------------------------------
  # CloudWatch logs
  # ---------------------------------------------------------------------------
  cloudwatch_name   = "/jenkins/prod"
  retention_in_days = 30

  # ---------------------------------------------------------------------------
  # Backup -EFS → S3 via AWS DataSync
  # enable_backup = true creates an S3 bucket and a daily DataSync task.
  # force_delete_s3 = false keeps backups even after terraform destroy.
  # ---------------------------------------------------------------------------
  enable_backup   = false
  force_delete_s3 = false
  backup_schedule = "cron(0 6 ? * MON-FRI *)"  # weekdays 06:00 UTC

  # ---------------------------------------------------------------------------
  # Security groups
  # Each SG name must be unique. cidr_blocks = [] falls back to VPC subnet CIDRs.
  # Add entries to additional_security_groups to extend without replacing defaults.
  # ---------------------------------------------------------------------------
  security_groups = [
    {
      name = "jenkins-ingress"
      ingress_rules = [
        {
          from_port   = 8080
          to_port     = 8080
          protocol    = "tcp"
          cidr_blocks = []  # VPC subnet CIDRs -use create_alb=true for internet access
          description = "Jenkins UI -VPC only"
        },
        {
          from_port   = 8090
          to_port     = 8090
          protocol    = "tcp"
          cidr_blocks = []  # VPC subnet CIDRs
          description = "JNLP agent port -VPC only"
        }
      ]
      egress_rules = []
      tags = { Name = "Jenkins-sg-ingress" }
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
          cidr_blocks = []  # VPC subnet CIDRs - EFS mount targets are in VPC subnets
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
      tags = { Name = "Jenkins-sg-egress" }
    },
    {
      name = "jenkins-efs"
      ingress_rules = [
        {
          from_port   = 2049
          to_port     = 2049
          protocol    = "tcp"
          cidr_blocks = []  # VPC subnet CIDRs - allows EC2 instances to reach EFS mount targets
          description = "NFS from VPC subnets"
        }
      ]
      egress_rules = []
      tags = { Name = "Jenkins-sg-efs" }
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
      tags = { Name = "Jenkins-sg-agent" }
    }
  ]

  # Extra security groups to attach alongside the defaults above.
  # Use this to add custom rules without replacing the entire security_groups list.
  additional_security_groups = []
}
