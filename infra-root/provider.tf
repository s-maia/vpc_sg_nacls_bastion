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
    # bucket       = "VALUE COMES FROM -backend-config option"
    key          = "terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true #S3 native locking
  }
}