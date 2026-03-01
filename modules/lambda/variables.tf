variable "name" {
  description = "Lambda function name"
  type        = string
}

variable "source_dir" {
  description = "Path to Lambda source code directory"
  type        = string
}

variable "handler" {
  description = "Lambda handler"
  type        = string
  default     = "main.handler"
}

variable "runtime" {
  description = "Lambda runtime"
  type        = string
  default     = "python3.12"
}

variable "create_api_gateway" {
  description = "Create API Gateway HTTP API and attach to Lambda"
  type        = bool
  default     = false
}

variable "environment" {
  description = "Lambda environment variables"
  type        = map(string)
  default     = {}
}

variable "subnet_ids" {
  description = "Subnet IDs for Lambda VPC config"
  type        = list(string)
  default     = []
}

variable "security_group_ids" {
  description = "Security group IDs for Lambda VPC config"
  type        = list(string)
  default     = []
}
