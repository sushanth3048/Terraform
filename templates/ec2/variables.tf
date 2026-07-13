variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Project name used for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where EC2 instances will be deployed"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for EC2 instances"
  type        = list(string)
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "ami_id" {
  description = "Custom AMI ID (leave empty to use latest Amazon Linux 2023)"
  type        = string
  default     = ""
}

variable "instance_count" {
  description = "Number of EC2 instances (only used when use_autoscaling = false)"
  type        = number
  default     = 1
}

variable "associate_public_ip" {
  description = "Associate public IP address with instances"
  type        = bool
  default     = false
}

variable "root_volume_size" {
  description = "Root EBS volume size in GB"
  type        = number
  default     = 20
}

variable "root_volume_type" {
  description = "Root EBS volume type (gp3, gp2, io1, io2)"
  type        = string
  default     = "gp3"
}

variable "encrypt_ebs" {
  description = "Encrypt EBS volumes with KMS"
  type        = bool
  default     = true
}

variable "create_key_pair" {
  description = "Create a new key pair for SSH access"
  type        = bool
  default     = false
}

variable "public_key" {
  description = "Public key material for the key pair (required when create_key_pair = true)"
  type        = string
  default     = ""
}

variable "existing_key_name" {
  description = "Name of an existing key pair to use"
  type        = string
  default     = null
}

variable "user_data" {
  description = "User data script to run on instance launch"
  type        = string
  default     = ""
}

variable "enable_detailed_monitoring" {
  description = "Enable detailed CloudWatch monitoring for EC2 instances"
  type        = bool
  default     = false
}

variable "ingress_rules" {
  description = "List of ingress rules for the security group"
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
    description = string
  }))
  default = [
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "HTTPS"
    }
  ]
}

variable "use_autoscaling" {
  description = "Use Auto Scaling Group instead of standalone instances"
  type        = bool
  default     = false
}

variable "asg_desired_capacity" {
  description = "Desired number of instances in the ASG"
  type        = number
  default     = 2
}

variable "asg_min_size" {
  description = "Minimum number of instances in the ASG"
  type        = number
  default     = 1
}

variable "asg_max_size" {
  description = "Maximum number of instances in the ASG"
  type        = number
  default     = 4
}

variable "asg_health_check_type" {
  description = "Health check type for ASG (EC2 or ELB)"
  type        = string
  default     = "EC2"
}

variable "tags" {
  description = "A map of tags to apply to all resources"
  type        = map(string)
  default     = {}
}
