
output "security_group_ids" {
  value = { for sg in aws_security_group.this : sg.name => sg.id }
}
