data "archive_file" "kafka_submit" {
  type        = "zip"
  source_dir  = "${path.module}/kafka-submit"
  output_path = "${path.module}/build/kafka-submit.zip"
}

resource "aws_iam_role" "kafka_submit" {
  name = "${var.project_name}-lambda-role"

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

resource "aws_iam_role_policy_attachment" "kafka_submit_basic" {
  role       = aws_iam_role.kafka_submit.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "kafka_submit" {
  filename         = data.archive_file.kafka_submit.output_path
  function_name    = var.project_name
  role             = aws_iam_role.kafka_submit.arn
  handler          = "main.handler"
  source_code_hash = data.archive_file.kafka_submit.output_base64sha256
  runtime          = "python3.12"

  # TODO: Add environment variables for Kafka config when needed
  # environment {
  #   variables = {
  #     KAFKA_BOOTSTRAP_SERVERS = "..."
  #   }
  # }
}
