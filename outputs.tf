
output "security_group_ids" {
  description = "Map of security group name to ID for all managed SGs."
  value       = { for sg in aws_security_group.this : sg.name => sg.id }
}

output "ecs_cluster_name" {
  description = "Name of the Jenkins ECS cluster."
  value       = aws_ecs_cluster.jenkins.name
}

output "ecs_cluster_arn" {
  description = "ARN of the Jenkins ECS cluster."
  value       = aws_ecs_cluster.jenkins.arn
}

output "efs_id" {
  description = "ID of the EFS filesystem used for jenkins_home persistence."
  value       = aws_efs_file_system.efs.id
}

output "cloudwatch_log_group_name" {
  description = "CloudWatch log group name for Jenkins container logs."
  value       = aws_cloudwatch_log_group.Jenkins.name
}

output "alb_dns_name" {
  description = "DNS name of the ALB. Null when create_alb is false."
  value       = var.create_alb ? aws_lb.jenkins[0].dns_name : null
}

output "alb_arn" {
  description = "ARN of the ALB. Null when create_alb is false."
  value       = var.create_alb ? aws_lb.jenkins[0].arn : null
}

output "jenkins_url" {
  description = "Jenkins access URL."
  value = var.create_alb ? (
    length(var.certificate_arn) > 0
    ? "https://${aws_lb.jenkins[0].dns_name}"
    : "http://${aws_lb.jenkins[0].dns_name}"
  ) : "No ALB created — access Jenkins on port 8080 of the EC2 instance."
}

output "backup_s3_bucket" {
  description = "S3 bucket name used for EFS backups. Null when enable_backup is false."
  value       = var.enable_backup ? aws_s3_bucket.jenkins[0].bucket : null
}
