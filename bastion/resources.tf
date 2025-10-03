# AMI
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["137112412989"] # Amazon
  filter {
    name   = "name"
    values = ["al2023-ami-*x86_64*"]
  }
}

# IAM for SSM
resource "aws_iam_role" "bastion_role" {
  name = "${local.name_prefix}-bastion-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "bastion_ssm_core" {
  role       = aws_iam_role.bastion_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "bastion_profile" {
  name = "${local.name_prefix}-bastion-profile"
  role = aws_iam_role.bastion_role.name
}

# Bastion instance (no key_name; no port 22)
resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  subnet_id              = var.public_subnet_id
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.bastion_profile.name

  user_data = <<-EOF
    #!/bin/bash
    set -euo pipefail
    if grep -q "^#PasswordAuthentication yes" /etc/ssh/sshd_config; then
      sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
      systemctl restart sshd || true
    fi
  EOF

  metadata_options { http_tokens = "required" }

  tags = { Name = "${local.name_prefix}-bastion" }
}

output "bastion_instance_id"  { value = aws_instance.bastion.id }
output "bastion_public_ip"    { value = aws_instance.bastion.public_ip }
output "bastion_private_ip"   { value = aws_instance.bastion.private_ip }
