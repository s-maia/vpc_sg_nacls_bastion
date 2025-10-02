variable "project" {
  type        = string
  description = "Name of the project, used for naming and tagging resources"
}

variable "environment" {
  type        = string
  description = "Deployment environment name"
}

variable "instance_type" {
  type    = string
  # default = "t3.micro"
}

variable "ssh_key_name" {
  type    = string
  default = null
}

variable "public_subnet_id" {
  type        = string
  description = "Public subnet ID where the bastion will live"
}

variable "bastion_sg_id" {
  type        = string
  description = "Security Group ID to attach to bastion"
}

variable "admin_cidrs" {
  type        = list(string)
  description = "Trusted admin public CIDRs for SSH"
}