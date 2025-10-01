output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.assignment1_vpc.id
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = [for _, s in aws_subnet.public : s.id]
}


output "bastion_sg_id" {
  description = "Bastion SG ID"
  value       = aws_security_group.bastion_sg.id
}

output "app_sg_id" {
  description = "App tier SG ID"
  value       = aws_security_group.app_sg.id
}
