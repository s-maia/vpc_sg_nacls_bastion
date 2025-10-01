locals {
  name_prefix = "${var.project}-${var.environment}"
  azs         = var.availability_zone
  public_map = { for i, az in local.azs : az => { az = az, cidr = var.public_subnet_cidrs[i] } }
  app_map    = { for i, az in local.azs : az => { az = az, cidr = var.private_app_subnet_cidrs[i] } }
  data_map   = { for i, az in local.azs : az => { az = az, cidr = var.private_data_subnet_cidrs[i] } }

  public_cidrs = var.public_subnet_cidrs
  app_cidrs    = var.private_app_subnet_cidrs
  data_cidrs   = var.private_data_subnet_cidrs

  #-- nacls ---
  ephemeral_from = 1024
  ephemeral_to   = 65535
  }