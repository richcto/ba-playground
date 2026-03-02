terraform {
  required_version = ">= 1.0"

  backend "s3" {
    bucket = "terraform-state-237617081322"
    key    = "ba-playground/terraform.tfstate"
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
    # kafka = {
    #   source  = "Mongey/kafka"
    #   version = "~> 0.7"
    # }
  }
}

provider "aws" {
  region = var.aws_region
}

# provider "kafka" {
#   bootstrap_servers = length(var.kafka_bootstrap_servers) > 0 ? [var.kafka_bootstrap_servers] : [""]
#   tls_enabled      = false
# }
