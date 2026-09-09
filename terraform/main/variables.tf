variable "aws_region" {
  description = "AWS region for the practice environment"
  type        = string
  default     = "ap-south-1"
}

variable "project" {
  description = "Project name, used as a prefix/tag on everything"
  type        = string
  default     = "ecom-platform"
}

variable "admin_cidr" {
  description = "Your own public IP in CIDR form (e.g. 203.0.113.5/32) — locks SSH and kube-API access down to just you. No default on purpose: you must set this explicitly in terraform.tfvars (gitignored) so it's never accidentally left open."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Two public subnets across two AZs (RDS requires a subnet group spanning >=2 AZs even for a single-AZ instance)"
  type        = list(string)
  default     = ["10.20.1.0/24", "10.20.2.0/24"]
}

variable "azs" {
  description = "Availability zones to spread subnets across"
  type        = list(string)
  default     = ["ap-south-1a", "ap-south-1b"]
}
