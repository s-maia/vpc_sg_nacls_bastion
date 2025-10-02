project     = "cicd-assignment"
environment = "production"

availability_zone         = ["us-east-1a", "us-east-1b"]
vpc_cidr                  = "10.10.0.0/16"
public_subnet_cidrs       = ["10.10.0.0/24", "10.10.1.0/24"]
private_app_subnet_cidrs  = ["10.10.10.0/24", "10.10.11.0/24"]
private_data_subnet_cidrs = ["10.10.20.0/24", "10.10.21.0/24"]

admin_cidrs = ["45.30.54.169/32"]
table_name  = "megazone_prod_table"
