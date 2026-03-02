data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = var.source_dir
  output_path = "${path.module}/build/${var.name}.zip"
}

resource "aws_iam_role" "lambda" {
  name = "${var.name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "additional" {
  count = var.additional_role_policy != null ? 1 : 0

  name   = var.additional_role_policy.name
  role   = aws_iam_role.lambda.id
  policy = var.additional_role_policy.document
}

resource "aws_lambda_function" "this" {
  filename         = data.archive_file.lambda.output_path
  function_name    = var.name
  role             = aws_iam_role.lambda.arn
  handler          = var.handler
  source_code_hash = data.archive_file.lambda.output_base64sha256
  runtime          = var.runtime
  timeout          = var.timeout

  dynamic "environment" {
    for_each = length(var.environment) > 0 ? [1] : []
    content {
      variables = var.environment
    }
  }

  dynamic "vpc_config" {
    for_each = length(var.subnet_ids) > 0 && length(var.security_group_ids) > 0 ? [1] : []
    content {
      subnet_ids         = var.subnet_ids
      security_group_ids = var.security_group_ids
    }
  }
}

# API Gateway (optional)
resource "aws_apigatewayv2_api" "this" {
  count = var.create_api_gateway ? 1 : 0

  name          = "${var.name}-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_headers = ["content-type", "authorization"]
  }
}

resource "aws_apigatewayv2_integration" "this" {
  count = var.create_api_gateway ? 1 : 0

  api_id                 = aws_apigatewayv2_api.this[0].id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.this.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "get" {
  count = var.create_api_gateway ? 1 : 0

  api_id    = aws_apigatewayv2_api.this[0].id
  route_key = "GET /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.this[0].id}"
}

resource "aws_apigatewayv2_route" "post" {
  count = var.create_api_gateway ? 1 : 0

  api_id    = aws_apigatewayv2_api.this[0].id
  route_key = "POST /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.this[0].id}"
}

resource "aws_apigatewayv2_route" "root_get" {
  count = var.create_api_gateway ? 1 : 0

  api_id    = aws_apigatewayv2_api.this[0].id
  route_key = "GET /"
  target    = "integrations/${aws_apigatewayv2_integration.this[0].id}"
}

resource "aws_apigatewayv2_route" "produce_get" {
  count = var.create_api_gateway ? 1 : 0

  api_id    = aws_apigatewayv2_api.this[0].id
  route_key = "GET /produce"
  target    = "integrations/${aws_apigatewayv2_integration.this[0].id}"
}

resource "aws_apigatewayv2_route" "root_post" {
  count = var.create_api_gateway ? 1 : 0

  api_id    = aws_apigatewayv2_api.this[0].id
  route_key = "POST /"
  target    = "integrations/${aws_apigatewayv2_integration.this[0].id}"
}

resource "aws_apigatewayv2_stage" "default" {
  count = var.create_api_gateway ? 1 : 0

  api_id      = aws_apigatewayv2_api.this[0].id
  name        = "prod"
  auto_deploy = true
}

resource "aws_lambda_permission" "api_gateway" {
  count = var.create_api_gateway ? 1 : 0

  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this[0].execution_arn}/*/*"
}
