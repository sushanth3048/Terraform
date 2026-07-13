terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Data source for latest AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Security Group
resource "aws_security_group" "ec2" {
  name        = "${var.project}-${var.environment}-ec2-sg"
  description = "Security group for EC2 instances"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = var.ingress_rules
    content {
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
      description = ingress.value.description
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.project}-${var.environment}-ec2-sg" })
}

# IAM Instance Profile
resource "aws_iam_role" "ec2" {
  name = "${var.project}-${var.environment}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project}-${var.environment}-ec2-profile"
  role = aws_iam_role.ec2.name
}

# Key Pair (optional)
resource "aws_key_pair" "ec2" {
  count      = var.create_key_pair ? 1 : 0
  key_name   = "${var.project}-${var.environment}-key"
  public_key = var.public_key

  tags = var.tags
}

# EBS Volume encryption key
resource "aws_kms_key" "ebs" {
  count                   = var.encrypt_ebs ? 1 : 0
  description             = "KMS key for EBS encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = var.tags
}

# Launch Template
resource "aws_launch_template" "main" {
  name_prefix   = "${var.project}-${var.environment}-"
  image_id      = var.ami_id != "" ? var.ami_id : data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  key_name      = var.create_key_pair ? aws_key_pair.ec2[0].key_name : var.existing_key_name

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2.name
  }

  network_interfaces {
    associate_public_ip_address = var.associate_public_ip
    security_groups             = [aws_security_group.ec2.id]
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = var.root_volume_size
      volume_type           = var.root_volume_type
      delete_on_termination = true
      encrypted             = var.encrypt_ebs
      kms_key_id            = var.encrypt_ebs ? aws_kms_key.ebs[0].arn : null
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"  # IMDSv2 enforced
    http_put_response_hop_limit = 1
  }

  monitoring {
    enabled = var.enable_detailed_monitoring
  }

  user_data = var.user_data != "" ? base64encode(var.user_data) : null

  tag_specifications {
    resource_type = "instance"
    tags          = merge(var.tags, { Name = "${var.project}-${var.environment}-ec2" })
  }

  tag_specifications {
    resource_type = "volume"
    tags          = merge(var.tags, { Name = "${var.project}-${var.environment}-volume" })
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Single EC2 Instance (when not using ASG)
resource "aws_instance" "main" {
  count = var.use_autoscaling ? 0 : var.instance_count

  launch_template {
    id      = aws_launch_template.main.id
    version = "$Latest"
  }

  subnet_id = var.subnet_ids[count.index % length(var.subnet_ids)]

  tags = merge(var.tags, { Name = "${var.project}-${var.environment}-ec2-${count.index + 1}" })
}

# Auto Scaling Group (when use_autoscaling = true)
resource "aws_autoscaling_group" "main" {
  count               = var.use_autoscaling ? 1 : 0
  name                = "${var.project}-${var.environment}-asg"
  desired_capacity    = var.asg_desired_capacity
  min_size            = var.asg_min_size
  max_size            = var.asg_max_size
  vpc_zone_identifier = var.subnet_ids

  launch_template {
    id      = aws_launch_template.main.id
    version = "$Latest"
  }

  health_check_type         = var.asg_health_check_type
  health_check_grace_period = 300

  dynamic "tag" {
    for_each = merge(var.tags, { Name = "${var.project}-${var.environment}-ec2" })
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}
