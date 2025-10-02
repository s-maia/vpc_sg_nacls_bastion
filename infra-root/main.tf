module "vpc" {
  source                    = "../vpc"
  vpc_cidr                  = var.vpc_cidr
  public_subnet_cidrs       = var.public_subnet_cidrs
  private_app_subnet_cidrs  = var.private_app_subnet_cidrs
  private_data_subnet_cidrs = var.private_data_subnet_cidrs
  availability_zone         = var.availability_zone
  project                   = var.project
  environment               = var.environment
  admin_cidrs               = var.admin_cidrs
}

module "bastion" {
  source           = "../bastion"
  project          = var.project
  environment      = var.environment
  instance_type    = var.instance_type
  ssh_key_name     = var.ssh_key_name
  public_subnet_id = module.vpc.public_subnet_ids[0]
  bastion_sg_id    = module.vpc.bastion_sg_id
}

module "webhook_states_table" {
  source         = "../dynamodb_table"
  table_name     = var.table_name
  main_table_key = "id"
  environment    = var.environment
  project        = var.project
  table_billing  = "PAY_PER_REQUEST"
}