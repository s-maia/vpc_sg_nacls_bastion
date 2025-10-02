provider "aws" {
  region = "us-east-1"
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    # bucket       = "megazonecloud-s3"
    # key          = "prod/infra-root/terraform.tfstate"
    # region       = "us-east-1"
    # use_lockfile = true
  }
}