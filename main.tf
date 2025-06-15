
locals {
  combined_security_groups = concat(var.security_groups, var.additional_security_groups)
  subnet_cidr_blocks       = [for subnet in data.aws_subnet.public : subnet.cidr_block]
  ami_id                   = data.aws_ssm_parameter.ecs_ami.value
}

data "aws_region" "current" {}
data "docker_registry_image" "jenkins" {
  name = var.jenkins_image
}
data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
}
data "aws_subnet" "public" {
  for_each = toset(data.aws_subnets.public.ids)
  id       = each.value
}
data "aws_vpc" "current" {
  id = var.vpc_id
}

data "aws_ssm_parameter" "ecs_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
}

# Iam policy
data "aws_iam_policy_document" "policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type = "Service"
      identifiers = [
        "ecs-tasks.amazonaws.com",
        "ecs.amazonaws.com",
        "ec2.amazonaws.com",
        "datasync.amazonaws.com"
      ]
    }
  }
}
data "aws_iam_policy" "jenkins" {
  for_each = toset([
    "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceEventsRole",
    "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceRole",
    "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
  ])
  arn = each.key
}

resource "aws_security_group" "this" {
  for_each = { for sg in local.combined_security_groups : sg.name => sg }

  name = each.value.name

  dynamic "ingress" {
    for_each = each.value.ingress_rules
    content {
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = length(ingress.value.cidr_blocks) > 0 ? ingress.value.cidr_blocks : local.subnet_cidr_blocks
      self        = lookup(ingress.value, "self", false)
      description = ingress.value.description
    }
  }

  dynamic "egress" {
    for_each = each.value.egress_rules
    content {
      from_port   = egress.value.from_port
      to_port     = egress.value.to_port
      protocol    = egress.value.protocol
      cidr_blocks = length(egress.value.cidr_blocks) > 0 ? egress.value.cidr_blocks : local.subnet_cidr_blocks
      self        = lookup(egress.value, "self", false)
      description = egress.value.description
    }
  }

  tags = each.value.tags
}


resource "null_resource" "update_plugins" {
  count = var.enable_update_plugins ? 1 : 0
  provisioner "local-exec" {
    command = "bash ${path.module}/script/plugins_update.sh"
    environment = {
      JENKINS_URL = var.jenkins_url
    }
  }

  triggers = {
    sha256_digest = data.docker_registry_image.jenkins.sha256_digest
    jenkins_url   = var.jenkins_url
  }
}


#------Iam role to be attached with ec2 -----
resource "aws_iam_role" "host_role_jenkins" {
  name_prefix        = "jenkins_ecsInstanceRole"
  assume_role_policy = data.aws_iam_policy_document.policy.json
  lifecycle {
    create_before_destroy = true
  }
}

#------Attach policy to EC2------
resource "aws_iam_role_policy_attachment" "jenkins" {
  for_each   = data.aws_iam_policy.jenkins
  policy_arn = each.value.arn
  role       = aws_iam_role.host_role_jenkins.name
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_instance_profile" "iam_instance_profile" {
  name_prefix = "jenkins_iam_instance_profile"
  path        = "/"
  role        = aws_iam_role.host_role_jenkins.name
  lifecycle {
    create_before_destroy = true
  }
}

#-----Create EFS file system----- 
resource "aws_efs_file_system" "efs" {
  creation_token   = var.efs_creation_token
  performance_mode = var.efs_performance_mode
  throughput_mode  = var.efs_throughput_mode
  encrypted        = true
  tags = {
    Name = "Jenkins_EFS"
  }
}

# -----Mount Target for EFS-----
resource "aws_efs_mount_target" "jenkins-efs-mount" {
  for_each        = toset(data.aws_subnets.public.ids)
  file_system_id  = aws_efs_file_system.efs.id
  subnet_id       = each.value
  security_groups = [aws_security_group.this["jenkins-efs"].id]
}

# ------Task definition ECS-----
resource "aws_ecs_task_definition" "Job" {
  family = "jenkins"
  container_definitions = templatefile("${path.module}/templates/jenkins.json.tpl", {
    image                    = "jenkins/jenkins@${data.docker_registry_image.jenkins.sha256_digest}",
    aws_log_group            = aws_cloudwatch_log_group.Jenkins.id,
    aws_region               = var.region,
    aws_prefix               = aws_cloudwatch_log_group.Jenkins.name
    jenkins_slave_agent_port = var.jenkins_slave_agent_port
    cpu                      = var.cpu
    memory                   = var.memory
    jenkins_url              = var.jenkins_url
  })
  task_role_arn = aws_iam_role.host_role_jenkins.arn
  volume {
    name = "jenkins_home"
    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.efs.id
      transit_encryption = "ENABLED"
    }
  }
  lifecycle {
    create_before_destroy = true
  }
}
#-----Starting Service in cpu cluster as Master1 -----
resource "aws_ecs_service" "jenkins" {
  name                 = "jenkins"
  cluster              = aws_ecs_cluster.jenkins.id
  task_definition      = aws_ecs_task_definition.Job.arn
  desired_count        = 1
  force_new_deployment = true
  depends_on           = [aws_autoscaling_group.asg_jenkins]
}

#-----Define cluster-----
resource "aws_ecs_cluster" "jenkins" {
  name = "jenkins"

  lifecycle {
    create_before_destroy = true
  }
}

#-----Define capacity provider for the clusters-----
resource "aws_ecs_cluster_capacity_providers" "cluster_cp_ecs" {
  cluster_name = aws_ecs_cluster.jenkins.name
  capacity_providers = [
    aws_ecs_capacity_provider.cp_ecs_jenkins.name
  ]

  lifecycle {
    create_before_destroy = true
  }
}
#-----Creating capacity provider-----
resource "aws_ecs_capacity_provider" "cp_ecs_jenkins" {
  name = "provider_cpu"
  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.asg_jenkins.arn
    managed_termination_protection = "DISABLED"

    managed_scaling {
      maximum_scaling_step_size = 1
      minimum_scaling_step_size = 1
      status                    = "ENABLED"
      target_capacity           = 1
    }
  }
  lifecycle {
    create_before_destroy = true
  }
}

#-----Auto scaling group-----
resource "aws_autoscaling_group" "asg_jenkins" {
  name_prefix               = "Auto_Scaling_Group_Jenkins"
  min_size                  = var.min_instance_size
  max_size                  = var.max_instance_size
  health_check_type         = "EC2"
  health_check_grace_period = 300
  vpc_zone_identifier       = [for subnet in data.aws_subnet.public : subnet.id]
  wait_for_capacity_timeout = "5m"
  force_delete              = true

  mixed_instances_policy {
    instances_distribution {
      on_demand_base_capacity                  = 0
      on_demand_percentage_above_base_capacity = 1
      spot_instance_pools                      = 1
    }
    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.launch_template.id
        version            = "$Latest"
      }
      override {
        instance_type = var.instance_type
      }
    }
  }

  lifecycle {
    create_before_destroy = true
  }
  tag {
    key                 = "jenkis"
    value               = "jenkis-asg"
    propagate_at_launch = true
  }
}
# -----Define launch template-----
resource "aws_launch_template" "launch_template" {
  name_prefix   = "lc_Jenkins"
  instance_type = var.instance_type
  image_id      = length(var.ami_id) > 0 ? var.ami_id : local.ami_id
  user_data     = base64encode("${templatefile("${path.module}/script/instance_setup.sh", { cluster_name = "${aws_ecs_cluster.jenkins.name}" })}")
  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.this["jenkins-ingress"].id, aws_security_group.this["jenkins-efs"].id, aws_security_group.this["jenkins-egress"].id, aws_security_group.this["jenkins-agent"].id]
  }
  iam_instance_profile {
    name = aws_iam_instance_profile.iam_instance_profile.name
  }
  monitoring {
    enabled = true
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_cloudwatch_log_group" "Jenkins" {
  name              = var.cloudwatch_name
  retention_in_days = var.retention_in_days
}

# -----Backup-----

resource "random_id" "prefix" {
  count       = var.enable_backup ? 1 : 0
  byte_length = 2
}

resource "aws_s3_bucket" "jenkins" {
  count         = var.enable_backup ? 1 : 0
  bucket        = "${random_id.prefix[0].hex}-jenkins-backup"
  force_destroy = var.force_delete_s3

  tags = {
    Name = "jenkins"
  }
}
module "s3_location" {
  count  = var.enable_backup ? 1 : 0
  source = "aws-ia/datasync/aws//modules/datasync-locations"

  s3_locations = [
    {
      name          = "datasync-s3"
      s3_bucket_arn = aws_s3_bucket.jenkins[0].arn
      subdirectory  = "/"
      create_role   = true
      tags          = { project = "datasync-s3" }
    }
  ]
}


module "efs_location" {
  count  = var.enable_backup ? 1 : 0
  source = "aws-ia/datasync/aws//modules/datasync-locations"

  efs_locations = [
    {
      name                           = "datasync-efs"
      efs_file_system_arn            = aws_efs_file_system.efs.arn
      ec2_config_subnet_arn          = "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_vpc.current.owner_id}:subnet/${values(data.aws_subnet.public)[0].id}"
      ec2_config_security_group_arns = [aws_security_group.this["jenkins-efs"].arn, aws_security_group.this["jenkins-egress"].arn]
      tags                           = { project = "datasync-efs" }
    }
  ]

  depends_on = [aws_efs_mount_target.jenkins-efs-mount]
}


module "backup_tasks" {
  count  = var.enable_backup ? 1 : 0
  source = "aws-ia/datasync/aws//modules/datasync-task"

  datasync_tasks = [
    {
      name                     = "efs_to_s3"
      source_location_arn      = module.efs_location[0].efs_locations["datasync-efs"].arn
      destination_location_arn = module.s3_location[0].s3_locations["datasync-s3"].arn

      options = {
        posix_permissions = "NONE"
        uid               = "NONE"
        gid               = "NONE"
      }

      schedule_expression = var.backup_schedule
    }
  ]
}
