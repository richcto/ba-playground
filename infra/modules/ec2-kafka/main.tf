data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_subnet" "first" {
  id = tolist(data.aws_subnets.default.ids)[0]
}

# IAM role for EC2 with SSM
resource "aws_iam_role" "ec2_kafka" {
  name = "${var.name_prefix}-ec2-kafka-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_managed_core" {
  role       = aws_iam_role.ec2_kafka.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_kafka" {
  name = "${var.name_prefix}-ec2-kafka-profile"
  role = aws_iam_role.ec2_kafka.name
}

# User data: install Docker and run Kafka
locals {
  user_data = <<-EOT
    #!/bin/bash
    set -e
    exec > >(tee /var/log/user-data.log) 2>&1

    # Install Docker
    yum update -y
    yum install -y docker
    systemctl start docker
    systemctl enable docker

    # Wait for Elastic IP to be attached by Terraform
    sleep 90

    # Get instance IPs (IMDSv2)
    TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" -s)
    PUBLIC_IP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/public-ipv4)
    PRIVATE_IP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/local-ipv4)

    # Run Kafka (Apache Kafka KRaft) with dual listeners:
    # INTERNAL (9092): Schema Registry, in-VPC clients - advertised as private IP
    # EXTERNAL (9094): Laptop, Lambdas, tools - advertised as public IP
    docker run -d --name kafka --restart unless-stopped \
      -p 9092:9092 -p 9093:9093 -p 9094:9094 \
      -e KAFKA_NODE_ID=1 \
      -e KAFKA_PROCESS_ROLES=broker,controller \
      -e KAFKA_CONTROLLER_QUORUM_VOTERS=1@$${PRIVATE_IP}:9093 \
      -e KAFKA_CONTROLLER_LISTENER_NAMES=CONTROLLER \
      -e KAFKA_LISTENERS=INTERNAL://:9092,EXTERNAL://:9094,CONTROLLER://:9093 \
      -e KAFKA_ADVERTISED_LISTENERS=INTERNAL://$${PRIVATE_IP}:9092,EXTERNAL://$${PUBLIC_IP}:9094 \
      -e KAFKA_LISTENER_SECURITY_PROTOCOL_MAP=INTERNAL:PLAINTEXT,EXTERNAL:PLAINTEXT,CONTROLLER:PLAINTEXT \
      -e KAFKA_INTER_BROKER_LISTENER_NAME=INTERNAL \
      -e KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR=1 \
      -e KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR=1 \
      -e KAFKA_TRANSACTION_STATE_LOG_MIN_ISR=1 \
      apache/kafka:3.9.0

    echo "Kafka started: INTERNAL $${PRIVATE_IP}:9092, EXTERNAL $${PUBLIC_IP}:9094"
  EOT
}

# Security group
resource "aws_security_group" "ec2_kafka" {
  name        = "${var.name_prefix}-ec2-kafka-sg"
  description = "Security group for Kafka EC2 instance"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "Kafka INTERNAL (Schema Registry, in-VPC)"
    from_port   = 9092
    to_port     = 9092
    protocol    = "tcp"
    cidr_blocks = var.ingress_cidr_blocks
  }

  ingress {
    description = "Kafka CONTROLLER (KRaft broker-to-controller, self)"
    from_port   = 9093
    to_port     = 9093
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.default.cidr_block]
  }

  ingress {
    description = "Kafka EXTERNAL (laptop, Lambdas, tools)"
    from_port   = 9094
    to_port     = 9094
    protocol    = "tcp"
    cidr_blocks = var.ingress_cidr_blocks
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ingress_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-ec2-kafka-sg"
  }
}

# EC2 instance
resource "aws_instance" "kafka" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  subnet_id              = data.aws_subnet.first.id
  vpc_security_group_ids = [aws_security_group.ec2_kafka.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_kafka.name
  user_data              = local.user_data

  tags = {
    Name = "${var.name_prefix}-ec2-kafka"
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }
}

# Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# Elastic IP
resource "aws_eip" "kafka" {
  instance = aws_instance.kafka.id
  domain   = "vpc"

  tags = {
    Name = "${var.name_prefix}-ec2-kafka-eip"
  }
}
