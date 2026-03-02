variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "eu-west-2"
}

variable "aws_account_id" {
  description = "AWS account ID for deployment"
  type        = string
  default     = "237617081322"
}

variable "aws_role_name" {
  description = "IAM role name for GitHub Actions to assume"
  type        = string
  default     = "github-actions"
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "ba-playground"
}

variable "ec2_instance_type" {
  description = "EC2 instance type for Kafka"
  type        = string
  default     = "t3.micro"
}

variable "kafka_ingress_mode" {
  description = "Ingress mode for Kafka/SSH: 'restricted' (your IP only) or 'public' (0.0.0.0/0 for GitHub Actions)"
  type        = string
  default     = "restricted"
  validation {
    condition     = contains(["restricted", "public"], var.kafka_ingress_mode)
    error_message = "kafka_ingress_mode must be 'restricted' or 'public'."
  }
}

variable "kafka_allowed_ip" {
  description = "Your IP for restricted mode (CIDR /32)"
  type        = string
  default     = "109.151.168.190"
}
