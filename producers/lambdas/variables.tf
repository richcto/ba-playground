variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "eu-west-2"
}

variable "aws_profile" {
  description = "AWS profile for local dev. Set to empty string in CI (TF_VAR_aws_profile=)."
  type        = string
  default     = "rjones2102.work"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "kafka-submit"
}
