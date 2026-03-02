# DynamoDB table for Kafka consumer offsets (avoids Kafka consumer group coordinator)
resource "aws_dynamodb_table" "consumer_offsets" {
  name         = "${var.name_prefix}-kafka-consumer-offsets"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "topic_partition"

  attribute {
    name = "topic_partition"
    type = "S"
  }

  tags = {
    Name = "${var.name_prefix}-kafka-consumer-offsets"
  }
}

# EC2 Kafka (default VPC)
module "ec2_kafka" {
  source = "./modules/ec2-kafka"

  name_prefix   = var.name_prefix
  aws_region    = var.aws_region
  instance_type = var.ec2_instance_type
}

# Lambda producer (API Gateway)
module "producer" {
  source = "./modules/lambda"

  name               = "kafka-producer"
  source_dir         = "${path.module}/build/producer"
  create_api_gateway = true
  environment = {
    KAFKA_BOOTSTRAP_SERVERS = module.ec2_kafka.kafka_bootstrap_servers
  }
}

# Lambda consumer
module "consumer" {
  source = "./modules/lambda"

  name       = "kafka-consumer"
  source_dir = "${path.module}/build/consumer"
  timeout    = 15
  environment = {
    KAFKA_BOOTSTRAP_SERVERS = module.ec2_kafka.kafka_bootstrap_servers
    OFFSETS_TABLE_NAME      = aws_dynamodb_table.consumer_offsets.name
  }
  additional_role_policy = {
    name     = "dynamodb-offsets"
    document = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect   = "Allow"
          Action   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:Query"]
          Resource = [aws_dynamodb_table.consumer_offsets.arn]
        }
      ]
    })
  }
}
