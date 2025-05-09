# Input variables for the Terraform configuration

variable "aws_region" {
  description = "The AWS region to deploy the resources in"
  type        = string
}

variable "access_key" {
  description = "AWS access key"
  type        = string
  sensitive   = true
}

variable "secret_key" {
  description = "AWS secret key"
  type        = string
  sensitive   = true
}

variable "vpc_cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "instance_tenancy" {
  description = "Instance tenancy for the VPC"
  type        = string
}

variable "az_state" {
  description = "State of the availability zones"
  type        = string
}

variable "subnet_cidrs" {
  description = "CIDR blocks for the subnet"
  type        = list(string)
}

variable "subnet_count" {
  type        = number
  description = "Number of subnets to create"
}

variable "rt_cidr_block" {
  description = "CIDR block for the route table"
  type        = string
}

variable "ssh_port_cidr" {
  description = "CIDR block for SSH port"
  type        = list(string)
}

variable "http_port_cidr" {
  description = "CIDR block for HTTP port"
  type        = list(string)
}

variable "app_port" {
  description = "Application port for the instance"
  type        = number
}

variable "egress_cidr" {
  description = "CIDR block for egress traffic"
  type        = list(string)
}

variable "alb_health_check_path" {
  description = "Health check path for the ALB"
  type        = string
}

variable "volume_size" {
  description = "Size of the EBS volume in GB"
  type        = number
}

variable "ec2_instance_type" {
  description = "Type of the EC2 instance"
  type        = string
}

variable "ami_id" {
  description = "AMI ID for the EC2 instance"
  type        = string
}

variable "volume_type" {
  description = "Type of the EBS volume"
  type        = string
}

variable "asg_min_capacity" {
  description = "Minimum capacity of the Auto Scaling group"
  type        = number
}

variable "asg_max_capacity" {
  description = "Maximum capacity of the Auto Scaling group"
  type        = number
}

variable "asg_desired_capacity" {
  description = "Desired capacity of the Auto Scaling group"
  type        = number
}

variable "asg_grace_period" {
  description = "Grace period for the Auto Scaling group health check"
  type        = number
}

variable "asg_cooldown_period" {
  description = "Cooldown period for the Auto Scaling group"
  type        = number
}

variable "s3_transition_days" {
  description = "Number of days to transition the S3 object to Glacier"
  type        = number
}

variable "s3_transition_storage_class" {
  description = "Storage class to transition the S3 object to"
  type        = string
}