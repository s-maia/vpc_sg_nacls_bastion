#VPC
resource "aws_vpc" "assignment1_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.project}-${var.environment}-vpc"
  }
}

#Public Subnets
resource "aws_subnet" "public_subnet" {
  for_each = local.public_map

  vpc_id                  = aws_vpc.assignment1_vpc.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.project}-${var.environment}-public-${each.value.az}"
    Tier        = "public"
    AZ          = each.value.az
  }
}

#Private App Subnets
resource "aws_subnet" "private_subnet" {
  for_each = local.app_map

  vpc_id                  = aws_vpc.assignment1_vpc.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = false

  tags = {
    Name        = "${var.project}-${var.environment}-app-${each.value.az}"
    Tier        = "app"
    AZ          = each.value.az
  }
}

#Private Data Subnets
resource "aws_subnet" "private_data_subnet" {
  for_each = local.data_map

  vpc_id                  = aws_vpc.assignment1_vpc.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = false

  tags = {
    Name        = "${var.project}-${var.environment}-data-${each.value.az}"
    Tier        = "data"
    AZ          = each.value.az
  }
}

#Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.assignment1_vpc.id
  tags = {
    Name = "${local.name_prefix}-igw"
  }
}

#Public route table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.assignment1_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "${local.name_prefix}-public-rt"
  }
}

#Public route table association
resource "aws_route_table_association" "subnet_associations" {
  for_each       = aws_subnet.public_subnet
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public_rt.id
}

# One EIP per AZ
resource "aws_eip" "nat_eip" {
  for_each = aws_subnet.public_subnet
  domain   = "vpc"
  tags = {
    Name = "${local.name_prefix}-eip-${each.key}"
  }
}

# NAT Gateway in public subnet 
resource "aws_nat_gateway" "nat_gateway" {
  for_each      = aws_subnet.public_subnet
  allocation_id = aws_eip.nat_eip[each.key].id
  subnet_id     = aws_subnet.public_subnet[each.key].id
  depends_on    = [aws_internet_gateway.igw]
  tags = {
    Name = "${local.name_prefix}-nat-${each.key}"
  }
}

# App route tables per AZ 
resource "aws_route_table" "app_rt" {
  for_each = aws_subnet.private_subnet
  vpc_id   = aws_vpc.assignment1_vpc.id
  tags = { Name = "${local.name_prefix}-rtb-app-${each.key}" }
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway[each.key].id
  }
}

# App subnets association with route table
resource "aws_route_table_association" "app" {
  for_each       = aws_subnet.private_subnet
  subnet_id      = each.value.id
  route_table_id = aws_route_table.app_rt[each.key].id
}

# DB route table without acces to Internet
resource "aws_route_table" "data_rt" {
  for_each = toset(var.availability_zone)
  vpc_id   = aws_vpc.assignment1_vpc.id
  tags     = { Name = "${var.project}-${var.environment}-rtb-data-${each.key}" }
}

# DB association with route table
resource "aws_route_table_association" "data" {
  for_each       = toset(var.availability_zone)
  subnet_id      = aws_subnet.private_data_subnet[each.key].id
  route_table_id = aws_route_table.data_rt[each.key].id
}




# ------------ Security Groups -----------

# SG for Public Tier
resource "aws_security_group" "alb_sg" {
  vpc_id = aws_vpc.assignment1_vpc.id
  name   = "${local.name_prefix}-alb-sg"
  tags   = { Name = "${local.name_prefix}-alb-sg" }
}


# Security group for App Tier
resource "aws_security_group" "app_sg" {
  vpc_id = aws_vpc.assignment1_vpc.id
  name   = "${local.name_prefix}-app-sg"
  tags   = { Name = "${local.name_prefix}-app-sg" }
}

# SG for db (MOST ISOLATED) allow only DB port from App; no egress
resource "aws_security_group" "db_sg" {
  vpc_id = aws_vpc.assignment1_vpc.id
  name   = "${local.name_prefix}-db-sg"
  egress = []
  tags   = { Name = "${local.name_prefix}-db-sg" }
}

# Bastion SG (SSH only from my IP)
resource "aws_security_group" "bastion_sg" {
  vpc_id = aws_vpc.assignment1_vpc.id
  name   = "${local.name_prefix}-bastion-sg"
  tags   = { Name = "${local.name_prefix}-bastion-sg" }
}



# ---- Security group Rules -----

#ALB rules
# Ingress 
resource "aws_security_group_rule" "alb_ingress_https" {
  type              = "ingress"
  security_group_id = aws_security_group.alb_sg.id
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "HTTPS from Internet"
}

resource "aws_security_group_rule" "app_ingress_http_from_alb" {
  type                     = "ingress"
  security_group_id        = aws_security_group.app_sg.id
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb_sg.id
  description              = "HTTP from ALB (health checks)"
}

#App rules
# Ingress 443 from ALB SG
resource "aws_security_group_rule" "app_ingress_https_from_alb" {
  type                     = "ingress"
  security_group_id        = aws_security_group.app_sg.id
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb_sg.id
  description              = "HTTPS from ALB"
}

# Ingress 22 from Bastion SG
resource "aws_security_group_rule" "app_ingress_ssh_from_bastion" {
  type                     = "ingress"
  security_group_id        = aws_security_group.app_sg.id
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.bastion_sg.id
  description              = "SSH from Bastion"
}

# # Egress DB port to DB SG (e.g., MySQL 3306; switch to 5432 for Postgres)
# resource "aws_security_group_rule" "app_egress_db" {
#   type                     = "egress"
#   security_group_id        = aws_security_group.app_sg.id
#   from_port                = 5432
#   to_port                  = 5432
#   protocol                 = "tcp"
#   source_security_group_id = aws_security_group.db_sg.id
#   description              = "DB port to DB tier"
# }

# General outbound (updates, APIs) via NAT
resource "aws_security_group_rule" "app_egress_any_inet" {
  type              = "egress"
  security_group_id = aws_security_group.app_sg.id
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "General egress via NAT"
}

#DB rules
# Ingress DB port from App SG; no egress (most isolated)
resource "aws_security_group_rule" "db_ingress_from_app" {
  type                     = "ingress"
  security_group_id        = aws_security_group.db_sg.id
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.app_sg.id
  description              = "DB port from App tier"
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
  description       = "HTTP to Internet (if needed)"
}


# ------- NACLS -------

# Presentation layer NACLS
resource "aws_network_acl" "public_nacl" {
  vpc_id = aws_vpc.assignment1_vpc.id
  tags   = { Name = "${local.name_prefix}-public-nacl" }
}

# Inbound from Internet (clients)
resource "aws_network_acl_rule" "public_in_http" {
  network_acl_id = aws_network_acl.public_nacl.id
  rule_number    = 100
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 80
}

resource "aws_network_acl_rule" "public_in_https" {
  network_acl_id = aws_network_acl.public_nacl.id
  rule_number    = 110
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}

# Outbound to Internet (requests + replies)
resource "aws_network_acl_rule" "public_out_http" {
  network_acl_id = aws_network_acl.public_nacl.id
  rule_number    = 200
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 80
}

resource "aws_network_acl_rule" "public_out_https" {
  network_acl_id = aws_network_acl.public_nacl.id
  rule_number    = 210
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}

resource "aws_network_acl_rule" "public_out_ephemeral" {
  network_acl_id = aws_network_acl.public_nacl.id
  rule_number    = 220
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = local.ephemeral_from
  to_port        = local.ephemeral_to
}

# Associate to all public subnets
resource "aws_network_acl_association" "public_assoc" {
  for_each       = aws_subnet.public_subnet
  subnet_id      = each.value.id
  network_acl_id = aws_network_acl.public_nacl.id
}



# ----- Application layer NACLS -----

resource "aws_network_acl" "app_nacl" {
  vpc_id = aws_vpc.assignment1_vpc.id
  tags   = { Name = "${local.name_prefix}-app-nacl" }
}

# Inbound from VPC (ALB + Bastion live in the VPC too)
resource "aws_network_acl_rule" "app_in_http_from_vpc" {
  network_acl_id = aws_network_acl.app_nacl.id
  rule_number    = 100
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = var.vpc_cidr
  from_port      = 80
  to_port        = 80
}

resource "aws_network_acl_rule" "app_in_https_from_vpc" {
  network_acl_id = aws_network_acl.app_nacl.id
  rule_number    = 110
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = var.vpc_cidr
  from_port      = 443
  to_port        = 443
}

resource "aws_network_acl_rule" "app_in_ssh_from_vpc" {
  network_acl_id = aws_network_acl.app_nacl.id
  rule_number    = 120
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = var.vpc_cidr
  from_port      = 22
  to_port        = 22
}

# Inbound ephemeral from VPC (responses)
resource "aws_network_acl_rule" "app_in_ephemeral_from_vpc" {
  network_acl_id = aws_network_acl.app_nacl.id
  rule_number    = 130
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = var.vpc_cidr
  from_port      = local.ephemeral_from
  to_port        = local.ephemeral_to
}

# Outbound to Internet (via NAT) and to DB
resource "aws_network_acl_rule" "app_out_http_inet" {
  network_acl_id = aws_network_acl.app_nacl.id
  rule_number    = 200
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 80
}

resource "aws_network_acl_rule" "app_out_https_inet" {
  network_acl_id = aws_network_acl.app_nacl.id
  rule_number    = 210
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}

resource "aws_network_acl_rule" "app_out_db_to_vpc" {
  network_acl_id = aws_network_acl.app_nacl.id
  rule_number    = 220
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = var.vpc_cidr
  from_port      = 5432
  to_port        = 5432
}

resource "aws_network_acl_rule" "app_out_ephemeral_to_vpc" {
  network_acl_id = aws_network_acl.app_nacl.id
  rule_number    = 230
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = var.vpc_cidr
  from_port      = local.ephemeral_from
  to_port        = local.ephemeral_to
}

# Associate to all app subnets
resource "aws_network_acl_association" "app_assoc" {
  for_each       = aws_subnet.private_subnet
  subnet_id      = each.value.id
  network_acl_id = aws_network_acl.app_nacl.id
}


# ----- DATABASE NACL  -----

resource "aws_network_acl" "database_nacl" {
  vpc_id = aws_vpc.assignment1_vpc.id
  tags   = { Name = "${local.name_prefix}-data-nacl" }
}

# Inbound DB from VPC (app servers live in VPC)
resource "aws_network_acl_rule" "data_in_db_from_vpc" {
  network_acl_id = aws_network_acl.database_nacl.id
  rule_number    = 100
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = var.vpc_cidr
  from_port      = 5432
  to_port        = 5432
}

# Outbound ephemeral to VPC (responses)
resource "aws_network_acl_rule" "data_out_ephemeral_to_vpc" {
  network_acl_id = aws_network_acl.database_nacl.id
  rule_number    = 200
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = var.vpc_cidr
  from_port      = local.ephemeral_from
  to_port        = local.ephemeral_to
}

# Associate to all data subnets
resource "aws_network_acl_association" "data_assoc" {
  for_each       = aws_subnet.private_data_subnet
  subnet_id      = each.value.id
  network_acl_id = aws_network_acl.database_nacl.id
}