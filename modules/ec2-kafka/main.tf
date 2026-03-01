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

    # Get instance public IP for Kafka advertised listeners
    PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

    # Create Docker network for Kafka and Zookeeper
    docker network create kafka-net || true

    # Run Zookeeper (required by cp-kafka)
    docker run -d --name zookeeper --restart unless-stopped --network kafka-net \
      -e ZOOKEEPER_CLIENT_PORT=2181 \
      -e ZOOKEEPER_TICK_TIME=2000 \
      confluentinc/cp-zookeeper:latest

    # Wait for Zookeeper to be ready
    sleep 15

    # Run Kafka
    docker run -d --name kafka --restart unless-stopped --network kafka-net \
      -p 9092:9092 \
      -e KAFKA_BROKER_ID=1 \
      -e KAFKA_ZOOKEEPER_CONNECT=zookeeper:2181 \
      -e KAFKA_ADVERTISED_LISTENERS=PLAINTEXT://$${PUBLIC_IP}:9092 \
      -e KAFKA_LISTENER_SECURITY_PROTOCOL_MAP=PLAINTEXT:PLAINTEXT \
      -e KAFKA_INTER_BROKER_LISTENER_NAME=PLAINTEXT \
      confluentinc/cp-kafka:latest

    echo "Kafka started on $${PUBLIC_IP}:9092"
  EOT
}

# Security group
resource "aws_security_group" "ec2_kafka" {
  name        = "${var.name_prefix}-ec2-kafka-sg"
  description = "Security group for Kafka EC2 instance"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "Kafka broker"
    from_port   = var.kafka_port
    to_port     = var.kafka_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
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
