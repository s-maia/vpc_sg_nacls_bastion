project     = "terraform-assignment"
environment = "staging"

availability_zone         = ["us-east-1a", "us-east-1b"]
vpc_cidr                  = "10.15.0.0/16"
public_subnet_cidrs       = ["10.15.0.0/24", "10.15.1.0/24"]
private_app_subnet_cidrs  = ["10.15.10.0/24", "10.15.11.0/24"]
private_data_subnet_cidrs = ["10.15.20.0/24", "10.15.21.0/24"]

admin_cidrs = ["45.30.54.169/32"]
