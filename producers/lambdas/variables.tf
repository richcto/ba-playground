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

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "kafka-submit"
}
