data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Lambda security group - allow outbound; Kafka/Schema Registry allow inbound from this
resource "aws_security_group" "lambda" {
  name        = "${var.name_prefix}-lambda-sg"
  description = "Security group for producer/consumer Lambdas"
  vpc_id      = data.aws_vpc.default.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-lambda-sg"
  }
}

# Allow Lambda to reach Kafka INTERNAL listener (9092)
resource "aws_security_group_rule" "kafka_from_lambda" {
  type                     = "ingress"
  from_port                = 9092
  to_port                  = 9092
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.lambda.id
  security_group_id        = module.ec2_kafka.security_group_id
  description              = "Kafka INTERNAL from Lambda"
}

# Allow Lambda to reach Schema Registry (8081)
resource "aws_security_group_rule" "schema_registry_from_lambda" {
  type                     = "ingress"
  from_port                = 8081
  to_port                  = 8081
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.lambda.id
  security_group_id        = module.ec2_schema_registry.security_group_id
  description              = "Schema Registry from Lambda"
}

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

  name_prefix         = var.name_prefix
  aws_region          = var.aws_region
  instance_type       = var.ec2_instance_type
  ingress_cidr_blocks = var.kafka_ingress_mode == "restricted" ? ["${var.kafka_allowed_ip}/32"] : ["0.0.0.0/0"]
}

# Allow Schema Registry to connect to Kafka on INTERNAL listener (9092)
# This rule adds ingress from Schema Registry SG - required for Schema Registry to reach Kafka
resource "aws_security_group_rule" "kafka_from_schema_registry" {
  depends_on = [module.ec2_kafka, module.ec2_schema_registry]

  type                     = "ingress"
  from_port                = 9092
  to_port                  = 9092
  protocol                 = "tcp"
  source_security_group_id = module.ec2_schema_registry.security_group_id
  security_group_id        = module.ec2_kafka.security_group_id
  description              = "Kafka INTERNAL from Schema Registry"
}

# EC2 Schema Registry
module "ec2_schema_registry" {
  source = "./modules/ec2-schema-registry"

  name_prefix             = var.name_prefix
  aws_region              = var.aws_region
  instance_type           = var.ec2_instance_type
  kafka_bootstrap_servers = "${module.ec2_kafka.kafka_private_ip}:9092"
  ingress_cidr_blocks     = var.kafka_ingress_mode == "restricted" ? ["${var.kafka_allowed_ip}/32"] : ["0.0.0.0/0"]
}

# Lambda producer (API Gateway) - in VPC to reach Kafka/Schema Registry via private IPs
module "producer" {
  source = "./modules/lambda"

  name               = "kafka-producer"
  source_dir         = "${path.module}/build/producer"
  create_api_gateway = true
  timeout            = 15
  subnet_ids         = data.aws_subnets.default.ids
  security_group_ids = [aws_security_group.lambda.id]
  environment = {
    KAFKA_BOOTSTRAP_SERVERS = "${module.ec2_kafka.kafka_private_ip}:9092"
    SCHEMA_REGISTRY_URL     = module.ec2_schema_registry.schema_registry_private_url
  }
}

# Lambda consumer - in VPC to reach Kafka/Schema Registry via private IPs
module "consumer" {
  source = "./modules/lambda"

  name               = "kafka-consumer"
  source_dir         = "${path.module}/build/consumer"
  create_api_gateway = true
  api_routes         = ["GET /consume/{topic}"]
  timeout            = 15
  subnet_ids         = data.aws_subnets.default.ids
  security_group_ids = [aws_security_group.lambda.id]
  environment = {
    KAFKA_BOOTSTRAP_SERVERS = "${module.ec2_kafka.kafka_private_ip}:9092"
    SCHEMA_REGISTRY_URL     = module.ec2_schema_registry.schema_registry_private_url
    OFFSETS_TABLE_NAME      = aws_dynamodb_table.consumer_offsets.name
  }
  additional_role_policy = {
    name = "dynamodb-offsets"
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
