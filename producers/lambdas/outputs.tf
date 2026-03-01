output "api_url" {
  description = "API Gateway URL"
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "lambda_function_name" {
  description = "Name of the Kafka submit Lambda function"
  value       = aws_lambda_function.kafka_submit.function_name
}
