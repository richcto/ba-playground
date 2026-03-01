resource "aws_apigatewayv2_api" "kafka_submit" {
  name          = "kafka-submit-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_headers = ["content-type", "authorization"]
  }
}

resource "aws_apigatewayv2_integration" "kafka_submit" {
  api_id              = aws_apigatewayv2_api.kafka_submit.id
  integration_type    = "AWS_PROXY"
  integration_uri     = aws_lambda_function.kafka_submit.invoke_arn
  integration_method  = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "get" {
  api_id    = aws_apigatewayv2_api.kafka_submit.id
  route_key = "GET /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.kafka_submit.id}"
}

resource "aws_apigatewayv2_route" "post" {
  api_id    = aws_apigatewayv2_api.kafka_submit.id
  route_key = "POST /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.kafka_submit.id}"
}

resource "aws_apigatewayv2_route" "root_get" {
  api_id    = aws_apigatewayv2_api.kafka_submit.id
  route_key = "GET /"
  target    = "integrations/${aws_apigatewayv2_integration.kafka_submit.id}"
}

resource "aws_apigatewayv2_route" "root_post" {
  api_id    = aws_apigatewayv2_api.kafka_submit.id
  route_key = "POST /"
  target    = "integrations/${aws_apigatewayv2_integration.kafka_submit.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.kafka_submit.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.kafka_submit.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.kafka_submit.execution_arn}/*/*"
}
