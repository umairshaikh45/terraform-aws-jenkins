resource "aws_security_group" "alb" {
  count  = var.create_alb ? 1 : 0
  name   = "jenkins-alb"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP"
  }

  dynamic "ingress" {
    for_each = length(var.certificate_arn) > 0 ? [1] : []
    content {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "HTTPS"
    }
  }

  egress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = local.subnet_cidr_blocks
    description = "Forward to Jenkins"
  }

  tags = { Name = "jenkins-alb-sg" }
}

# Separate SG attached to EC2 instances that allows inbound only from the ALB
resource "aws_security_group" "jenkins_from_alb" {
  count  = var.create_alb ? 1 : 0
  name   = "jenkins-from-alb"
  vpc_id = var.vpc_id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb[0].id]
    description     = "Allow HTTP from ALB only"
  }

  tags = { Name = "jenkins-from-alb-sg" }
}

resource "aws_lb" "jenkins" {
  count              = var.create_alb ? 1 : 0
  name               = "jenkins-alb"
  internal           = var.alb_internal
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb[0].id]
  subnets            = [for subnet in data.aws_subnet.public : subnet.id]

  enable_deletion_protection = var.alb_deletion_protection

  tags = { Name = "jenkins-alb" }
}

resource "aws_lb_target_group" "jenkins" {
  count                = var.create_alb ? 1 : 0
  name                 = "jenkins-tg"
  port                 = 8080
  protocol             = "HTTP"
  vpc_id               = var.vpc_id
  target_type          = "instance"
  deregistration_delay = 30  # seconds; default 300 causes slow ECS task drain on destroy

  health_check {
    path                = "/login"
    matcher             = "200"
    healthy_threshold   = 2
    unhealthy_threshold = 5
    interval            = 30
    timeout             = 10
  }

  tags = { Name = "jenkins-tg" }
}

# Plain HTTP listener — used when no TLS certificate is configured
resource "aws_lb_listener" "http" {
  count             = var.create_alb && length(var.certificate_arn) == 0 ? 1 : 0
  load_balancer_arn = aws_lb.jenkins[0].arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.jenkins[0].arn
  }
}

# HTTP → HTTPS redirect when a certificate is provided
resource "aws_lb_listener" "http_redirect" {
  count             = var.create_alb && length(var.certificate_arn) > 0 ? 1 : 0
  load_balancer_arn = aws_lb.jenkins[0].arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https" {
  count             = var.create_alb && length(var.certificate_arn) > 0 ? 1 : 0
  load_balancer_arn = aws_lb.jenkins[0].arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.jenkins[0].arn
  }
}
