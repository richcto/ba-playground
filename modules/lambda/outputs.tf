output "function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.this.function_name
}

output "function_arn" {
  description = "Lambda function ARN"
  value       = aws_lambda_function.this.arn
}

output "invoke_arn" {
  description = "Lambda invoke ARN"
  value       = aws_lambda_function.this.invoke_arn
}

output "api_url" {
  description = "API Gateway URL (when create_api_gateway is true)"
  value       = var.create_api_gateway ? aws_apigatewayv2_stage.default[0].invoke_url : null
}
