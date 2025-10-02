resource "aws_dynamodb_table" "dynamo_dbstates" {
  name         = var.table_name
  billing_mode = var.table_billing # This enables dynamic/on-demand capacity
  hash_key     = var.main_table_key

  attribute {
    name = var.main_table_key
    type = "S"
  }

  tags = {
    Environment = var.environment
    Project     = var.project
  }
}

variable "table_name" {
  type = string
}

variable "main_table_key" {
  type = string
}

variable "table_billing" {
  type = string
}

variable "project" {
  type = string
}

variable "environment" {
  type = string
}