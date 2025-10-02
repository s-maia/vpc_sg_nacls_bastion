data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["137112412989"] # Amazon

  filter {
    name   = "name"
    values = ["al2023-ami-*x86_64*"]
  }
}

resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  subnet_id              = var.public_subnet_id
  vpc_security_group_ids = [var.bastion_sg_id]
  iam_instance_profile   = aws_iam_instance_profile.bastion_profile.name
  key_name               = var.ssh_key_name

  user_data = <<-EOF
    #!/bin/bash
    set -euo pipefail
    sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
    systemctl restart sshd
  EOF
  metadata_options { http_tokens = "required" }

  tags = { Name = "${local.name_prefix}-bastion" }
}

# Bastion SG (SSH only from my IP)
resource "aws_security_group" "bastion_sg" {
  vpc_id = aws_vpc.assignment1_vpc.id
  name   = "${local.name_prefix}-bastion-sg"
  tags   = { Name = "${local.name_prefix}-bastion-sg" }
}

# --- Bastion rules ---
resource "aws_security_group_rule" "bastion_ingress_ssh_from_admin" {
  type              = "ingress"
  security_group_id = aws_security_group.bastion_sg.id
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = var.admin_cidrs
  description       = "SSH from admin IPs"
}

resource "aws_security_group_rule" "bastion_egress_ssh_to_app" {
  type                     = "egress"
  security_group_id        = aws_security_group.bastion_sg.id
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.app_sg.id
  description              = "SSH to App"
}

# Optional: allow package updates from bastion
resource "aws_security_group_rule" "bastion_egress_https" {
  type              = "egress"
  security_group_id = aws_security_group.bastion_sg.id
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "HTTPS to Internet"
}

resource "aws_security_group_rule" "bastion_egress_http" {
  type              = "egress"
  security_group_id = aws_security_group.bastion_sg.id
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "HTTP to Internet"
}
