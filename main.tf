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
  source_dir         = "${path.module}/lambdas/producer"
  create_api_gateway = true
}

# Lambda consumer
module "consumer" {
  source = "./modules/lambda"

  name       = "kafka-consumer"
  source_dir = "${path.module}/lambdas/consumer"
}
