module "vpc" {
  source                    = "../vpc"
  vpc_cidr                  = var.vpc_cidr
  public_subnet_cidrs       = var.public_subnet_cidrs
  private_app_subnet_cidrs  = var.private_app_subnet_cidrs
  private_data_subnet_cidrs = var.private_data_subnet_cidrs
  availability_zone         = var.availability_zone
  project                   = var.project
  environment               = var.environment
}

module "bastion" {
  source           = "../bastion"
  project          = var.project
  environment      = var.environment
  instance_type    = var.instance_type
  public_subnet_id = module.vpc.public_subnet_ids[0]
  bastion_sg_id    = module.vpc.bastion_sg_id
}