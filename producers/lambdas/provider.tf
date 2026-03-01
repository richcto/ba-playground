terraform {
  required_version = ">= 1.0"

  backend "s3" {
    bucket = "terraform-state-237617081322"
    key    = "ba-playground/producers-lambdas/terraform.tfstate"
    region = "eu-west-2"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}
