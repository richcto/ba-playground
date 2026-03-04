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
resource "aws_iam_role" "schema_registry" {
  name = "${var.name_prefix}-ec2-schema-registry-role"

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
  role       = aws_iam_role.schema_registry.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.schema_registry.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "schema_registry" {
  name = "${var.name_prefix}-ec2-schema-registry-profile"
  role = aws_iam_role.schema_registry.name
}

# User data: install Docker and run Schema Registry
locals {
  user_data = <<-EOT
    #!/bin/bash
    set -e
    exec > >(tee /var/log/user-data.log) 2>&1

    yum update -y
    yum install -y docker amazon-cloudwatch-agent
    systemctl start docker
    systemctl enable docker

    # CloudWatch agent config for memory monitoring (Python avoids nested heredoc issues)
    mkdir -p /opt/aws/amazon-cloudwatch-agent/etc
    python3 -c 'import json; json.dump({"metrics":{"namespace":"BA/SchemaRegistry","metrics_collected":{"mem":{"measurement":["mem_used_percent","mem_available","mem_used"],"metrics_collection_interval":60},"disk":{"measurement":["disk_used_percent"],"metrics_collection_interval":60}}}}, open("/opt/aws/amazon-cloudwatch-agent/etc/cw-agent.json","w"), indent=2)'
    /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/etc/cw-agent.json

    # Wait for Kafka to be ready
    sleep 90

    docker run -d --name schema-registry --restart unless-stopped \
      -p 8081:8081 \
      -e SCHEMA_REGISTRY_KAFKASTORE_BOOTSTRAP_SERVERS=${var.kafka_bootstrap_servers} \
      -e SCHEMA_REGISTRY_HOST_NAME=localhost \
      -e SCHEMA_REGISTRY_LISTENERS=http://0.0.0.0:8081 \
      -e SCHEMA_REGISTRY_HEAP_OPTS="-Xms256m -Xmx256m" \
      confluentinc/cp-schema-registry:7.6.0

    echo "Schema Registry started on 8081"
  EOT
}

# Security group
resource "aws_security_group" "schema_registry" {
  name        = "${var.name_prefix}-ec2-schema-registry-sg"
  description = "Security group for Schema Registry EC2 instance"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "Schema Registry API"
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = var.ingress_cidr_blocks
  }

  # Allow in-VPC clients (Lambda) - source_sg can fail with Lambda hyperplane ENIs
  ingress {
    description = "Schema Registry from VPC (Lambda)"
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.default.cidr_block]
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
    Name = "${var.name_prefix}-ec2-schema-registry-sg"
  }
}

# EC2 instance
resource "aws_instance" "schema_registry" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  subnet_id              = data.aws_subnet.first.id
  vpc_security_group_ids = [aws_security_group.schema_registry.id]
  iam_instance_profile   = aws_iam_instance_profile.schema_registry.name
  user_data              = local.user_data

  tags = {
    Name = "${var.name_prefix}-ec2-schema-registry"
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
resource "aws_eip" "schema_registry" {
  instance = aws_instance.schema_registry.id
  domain   = "vpc"

  tags = {
    Name = "${var.name_prefix}-ec2-schema-registry-eip"
  }
}
