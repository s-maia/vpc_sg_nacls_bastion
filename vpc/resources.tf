#VPC
resource "aws_vpc" "assignment1_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${local.name_prefix}-vpc"
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
    Name = "${local.name_prefix}-public-${each.value.az}"
    Tier = "public"
    AZ   = each.value.az
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
    Name = "${local.name_prefix}-app-${each.value.az}"
    Tier = "app"
    AZ   = each.value.az
  }
}

#Private Database Subnets
resource "aws_subnet" "private_data_subnet" {
  for_each = local.data_map

  vpc_id                  = aws_vpc.assignment1_vpc.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = false

  tags = {
    Name = "${local.name_prefix}-data-${each.value.az}"
    Tier = "data"
    AZ   = each.value.az
  }
}

# ------- ROUTING: IGW, NATs, RTs --------

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
# Associate all public subnets
resource "aws_route_table_association" "subnet_associations" {
  for_each       = aws_subnet.public_subnet
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public_rt.id
}

# NAT per AZ
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

# App RTs (egress via NAT)
resource "aws_route_table" "app_rt" {
  for_each = aws_subnet.private_subnet
  vpc_id   = aws_vpc.assignment1_vpc.id
  tags     = { Name = "${local.name_prefix}-rtb-app-${each.key}" }
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway[each.key].id
  }
}

resource "aws_route_table_association" "app" {
  for_each       = aws_subnet.private_subnet
  subnet_id      = each.value.id
  route_table_id = aws_route_table.app_rt[each.key].id
}

# Data RTs (no internet)
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
  egress = []
  tags   = { Name = "${local.name_prefix}-app-sg" }
}

# SG for DB 
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

# Egress ALB to App on 443 (primary path)
resource "aws_security_group_rule" "alb_egress_all" {
  type              = "egress"
  security_group_id = aws_security_group.alb_sg.id
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "ALB egress"
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

# App egress to DB (5432) within VPC
resource "aws_security_group_rule" "app_egress_db_cidr" {
  type              = "egress"
  security_group_id = aws_security_group.app_sg.id
  from_port         = 5432
  to_port           = 5432
  protocol          = "tcp"
  cidr_blocks       = var.private_data_subnet_cidrs
  description       = "App to DB on 5432"
}

# --- DB rules ---
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
  type              = "egress"
  security_group_id = aws_security_group.bastion_sg.id
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = var.private_app_subnet_cidrs
  description       = "SSH to App tier"
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


# ------- NACLS -------


# --- Public NACL (ALB + Bastion) ---
resource "aws_network_acl" "public_nacl" {
  vpc_id = aws_vpc.assignment1_vpc.id
  tags   = { Name = "${local.name_prefix}-public-nacl" }
}

# INBOUND 
# HTTPS/443 to ALB
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

# SSH/22 to bastion from admin IPs
resource "aws_network_acl_rule" "public_in_ssh_admin" {
  for_each       = toset(var.admin_cidrs) 
  network_acl_id = aws_network_acl.public_nacl.id
  rule_number    = 115 + index(var.admin_cidrs, each.key)
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = each.key
  from_port      = 22
  to_port        = 22
}

# Inbound ephemeral for return traffic to bastion’s outbound connections (stateless NACL)
resource "aws_network_acl_rule" "public_in_ephemeral" {
  network_acl_id = aws_network_acl.public_nacl.id
  rule_number    = 120
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = local.ephemeral_from  
  to_port        = local.ephemeral_to    
}

# OUTBOUND
# HTTPS to Internet (bastion updates, package repos, etc.)
resource "aws_network_acl_rule" "public_out_https" {
  network_acl_id = aws_network_acl.public_nacl.id
  rule_number    = 200
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}

# OPTIONAL: HTTP to Internet
resource "aws_network_acl_rule" "public_out_http" {
  network_acl_id = aws_network_acl.public_nacl.id
  rule_number    = 205
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 80
}

# ALB to App (tightened to App subnets)
resource "aws_network_acl_rule" "public_out_to_app_https" {
  for_each       = { for idx, cidr in local.app_cidrs : cidr => idx } 
  network_acl_id = aws_network_acl.public_nacl.id
  rule_number    = 210 + each.value
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = each.key
  from_port      = 443
  to_port        = 443
}

# Outbound ephemeral to Internet (responses to inbound HTTPS/SSH)
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



# --- Application layer NACLS ---

resource "aws_network_acl" "app_nacl" {
  vpc_id = aws_vpc.assignment1_vpc.id
  tags   = { Name = "${local.name_prefix}-app-nacl" }
}

# Inbound from PUBLIC (ALB/Bastion)
resource "aws_network_acl_rule" "app_in_https_from_public" {
  for_each       = { for idx, cidr in local.public_cidrs : cidr => idx }
  network_acl_id = aws_network_acl.app_nacl.id
  rule_number    = 100 + each.value
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = each.key
  from_port      = 443
  to_port        = 443
}

# SSH from Bastion
resource "aws_network_acl_rule" "app_in_ssh_from_vpc" {
  for_each       = { for idx, cidr in local.public_cidrs : cidr => idx }
  network_acl_id = aws_network_acl.app_nacl.id
  rule_number    = 110 + each.value
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = each.key
  from_port      = 22
  to_port        = 22
}

# # Inbound ephemeral from public (responses)
# resource "aws_network_acl_rule" "app_in_ephemeral_from_public" {
#   for_each       = { for idx, cidr in local.public_cidrs : cidr => idx }
#   network_acl_id = aws_network_acl.app_nacl.id
#   rule_number    = 120 + each.value
#   egress         = false
#   protocol       = "tcp"
#   rule_action    = "allow"
#   cidr_block     = each.key
#   from_port      = local.ephemeral_from
#   to_port        = local.ephemeral_to
# }

# INBOUND from DATA (responses to App→DB)
resource "aws_network_acl_rule" "app_in_ephemeral_from_data" {
  for_each       = { for idx, cidr in local.data_cidrs : cidr => idx }
  network_acl_id = aws_network_acl.app_nacl.id
  rule_number    = 140 + each.value
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = each.key
  from_port      = local.ephemeral_from
  to_port        = local.ephemeral_to
}

# Outbound to DB (App initiates DB)
resource "aws_network_acl_rule" "app_out_db_to_data" {
  for_each       = { for idx, cidr in local.data_cidrs : cidr => idx }
  network_acl_id = aws_network_acl.app_nacl.id
  rule_number    = 200 + each.value
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = each.key
  from_port      = 5432
  to_port        = 5432
}

# Outbound ephemeral to public (responses to inbound 443/22)
resource "aws_network_acl_rule" "app_out_ephemeral_to_public" {
  for_each       = { for idx, cidr in local.public_cidrs : cidr => idx }
  network_acl_id = aws_network_acl.app_nacl.id
  rule_number    = 220 + each.value
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = each.key
  from_port      = local.ephemeral_from
  to_port        = local.ephemeral_to
}

# Associate to all app subnets
resource "aws_network_acl_association" "app_assoc" {
  for_each       = aws_subnet.private_subnet
  subnet_id      = each.value.id
  network_acl_id = aws_network_acl.app_nacl.id
}


# --- DATABASE NACL  ---
resource "aws_network_acl" "database_nacl" {
  vpc_id = aws_vpc.assignment1_vpc.id
  tags   = { Name = "${local.name_prefix}-data-nacl" }
}

resource "aws_network_acl_rule" "data_in_db_from_app" {
  for_each       = { for idx, cidr in local.app_cidrs : cidr => idx }
  network_acl_id = aws_network_acl.database_nacl.id
  rule_number    = 100 + each.value
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = each.key
  from_port      = 5432
  to_port        = 5432
}

resource "aws_network_acl_rule" "data_out_ephemeral_to_app" {
  for_each       = { for idx, cidr in local.app_cidrs : cidr => idx }
  network_acl_id = aws_network_acl.database_nacl.id
  rule_number    = 200 + each.value
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = each.key
  from_port      = local.ephemeral_from
  to_port        = local.ephemeral_to
}

resource "aws_network_acl_association" "data_assoc" {
  for_each       = aws_subnet.private_data_subnet
  subnet_id      = each.value.id
  network_acl_id = aws_network_acl.database_nacl.id
}