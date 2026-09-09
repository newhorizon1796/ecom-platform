terraform {
  required_version = ">= 1.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "ecom-platform-tfstate-839931788764"
    key            = "terraform/main/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "ecom-platform-tflock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}
