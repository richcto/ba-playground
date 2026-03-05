terraform {
  required_version = ">= 1.0"

  backend "s3" {
    bucket = "terraform-state-237617081322"
    key    = "ba-playground/kafka/default.tfstate"
    region = "eu-west-2"
  }

  required_providers {
    kafka = {
      source  = "Mongey/kafka"
      version = "~> 0.7"
    }
  }
}

provider "kafka" {
  bootstrap_servers = [data.terraform_remote_state.infra.outputs.kafka_bootstrap_servers]
  tls_enabled       = false
}
