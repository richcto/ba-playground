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
