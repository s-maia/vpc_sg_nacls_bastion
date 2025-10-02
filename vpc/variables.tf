variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC to be created"
}

variable "project" {
  type        = string
  description = "Name of the project, used for naming and tagging resources"
}

variable "environment" {
  type        = string
  description = "Deployment environment name"
}

variable "availability_zone" {
  type = list(string)
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "CIDRs for public subnets, one per AZ."
  validation {
    condition     = length(var.public_subnet_cidrs) == length(var.availability_zone)
    error_message = "public_subnet_cidrs must match the number of availability_zone."
  }
}

variable "private_app_subnet_cidrs" {
  type        = list(string)
  description = "CIDRs for private app subnets, one per AZ."
  validation {
    condition     = length(var.private_app_subnet_cidrs) == length(var.availability_zone)
    error_message = "private_app_subnet_cidrs must match the number of availability_zone."
  }
}

variable "private_data_subnet_cidrs" {
  type        = list(string)
  description = "CIDRs for private data subnets, one per AZ."
  validation {
    condition     = length(var.private_data_subnet_cidrs) == length(var.availability_zone)
    error_message = "private_data_subnet_cidrs must match the number of availability_zone."
  }
}