# Configure terraform version and required providers
# This configuration specifies the required version of Terraform and the providers to be used
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "> 5.0, < 6.0"
    }
    tls = {
      source = "hashicorp/tls"
    }
  }
}

# Configure the AWS Provider 
# This provider will be used to create and manage AWS resources
# The access key and secret key are provided as variables for security reasons
provider "aws" {
  region     = var.aws_region
  access_key = var.access_key
  secret_key = var.secret_key
}

# Create a VPC for the resources
# This VPC will be used to host the EC2 instances and other resources
resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
  instance_tenancy     = var.instance_tenancy

  tags = {
    Name = "main"
  }
}

# Available availability zones in a region
data "aws_availability_zones" "available" {
  state = var.az_state
}

# Create a subnet within the VPC
# This subnet will be used to host the EC2 instances and other resources
resource "aws_subnet" "subnet" {
  count                   = var.subnet_count
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "main"
  }
}

# Create an Internet Gateway for the VPC
# This gateway will be used to route traffic from the public subnets to the internet
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "main"
  }
}

# Create a Public Route Table 
# This route table will be used to route traffic from the public subnets to the internet
resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = var.rt_cidr_block
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "main"
  }
}

# Public Route Table Associations 
# This resource associates the public subnets with the public route table
# This allows the subnets to route traffic to the internet through the internet gateway
resource "aws_route_table_association" "rt_association" {
  count          = var.subnet_count
  subnet_id      = aws_subnet.subnet[count.index].id
  route_table_id = aws_route_table.rt.id
}

# Create a Load Balancer Security Group
# This security group will be used to control access to the load balancer
resource "aws_security_group" "lb_sg" {
  name        = "load-balancer-security-group"
  description = "Allows internet traffic to the Load Balancer"
  vpc_id      = aws_vpc.vpc.id

  # This rule allows HTTP traffic to the load balancer from a specific CIDR block
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.http_port_cidr
  }

  # Egreess rule to allow all outbound traffic
  # This rule allows the load balancer to communicate with the internet and other resources
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = var.egress_cidr
  }

  tags = {
    Name = "load-balancer-security-group"
  }
}

# Create an Application Security Group
# This security group will be used to control access to the EC2 instances and other resources
resource "aws_security_group" "app_sg" {
  name   = "application-security-group"
  vpc_id = aws_vpc.vpc.id

  # This rule allows SSH access to the instances from a specific CIDR block
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_port_cidr
  }

  # This rule allows access to the application from a specific CIDR block
  ingress {
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.lb_sg.id]
  }

  # Egress rule to allow all outbound traffic
  # This rule allows the instances to communicate with the internet and other resources
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = var.egress_cidr
  }

  tags = {
    Name = "application-security-group"
  }
}

# Create an Application Load Balancer for the application
# This load balancer will distribute incoming traffic to the EC2 instances
# The load balancer is associated with the security group created above
resource "aws_lb" "alb" {
  name               = "app-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]
  subnets            = [for subnet in aws_subnet.subnet : subnet.id]

  tags = {
    Name = "alb"
  }
}

# Create a Target Group for the application instances
# This target group will be used to route traffic to the EC2 instances
resource "aws_lb_target_group" "tg" {
  name     = "app-tg"
  port     = var.app_port
  protocol = "HTTP"
  vpc_id   = aws_vpc.vpc.id

  health_check {
    path                = var.alb_health_check_path
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 90
    timeout             = 2
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# Create a listener for the Application Load Balancer to forward HTTP traffic to the target group
# This listener will listen on port 80 and forward traffic to the target group created above
resource "aws_lb_listener" "alb_listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

# Generate a new private key
# This key will be used to create an AWS key pair for the EC2 instances
# The private key will be saved to a local file for later use
resource "tls_private_key" "this" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create AWS key pair using the generated public key
# This key pair will be used to access the EC2 instances
# The public key is generated from the private key created above
resource "aws_key_pair" "this" {
  key_name   = "ec2-key-pair"
  public_key = tls_private_key.this.public_key_openssh
}

# Save private key to local file
resource "local_file" "private_key" {
  content  = tls_private_key.this.private_key_pem
  filename = "${path.module}/ec2-key-pair.pem"
}

# Get the app files content during Terraform execution
locals {
  app_js_content       = file("${path.module}/../app/app.js")
  package_json_content = file("${path.module}/../app/package.json")
}

# Create a launch template for the application instances
# This template will be used to create EC2 instances with the specified configuration
# The launch template includes the AMI ID, instance type, key pair, and other configurations
resource "aws_launch_template" "lt" {
  name_prefix   = "asg-lt"
  image_id      = var.ami_id
  instance_type = var.ec2_instance_type
  key_name      = aws_key_pair.this.key_name

  # Block device mappings for the instance
  # This configuration specifies the EBS volume size, type, and other settings  
  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size           = var.volume_size
      volume_type           = var.volume_type
      delete_on_termination = true
      encrypted             = true
    }
  }

  # Network interfaces for the instance
  # This configuration specifies the security group and other settings for the network interface
  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.app_sg.id]
  }

  # User data script to install and configure the application on the instance
  # This script will be executed when the instance is launched
  user_data = base64encode(templatefile("${path.module}/scripts/userdata.sh", {
    PORT                 = var.app_port
    app_js_content       = local.app_js_content
    package_json_content = local.package_json_content
  }))
}

# Create an Auto Scaling Group for the application instances
# This group will manage the scaling of the EC2 instances based on the specified configuration
# The Auto Scaling Group is associated with the launch template created above
resource "aws_autoscaling_group" "asg" {
  name                      = "asg"
  max_size                  = var.asg_max_capacity
  min_size                  = var.asg_min_capacity
  desired_capacity          = var.asg_desired_capacity
  vpc_zone_identifier       = [for subnet in aws_subnet.subnet : subnet.id]
  health_check_type         = "ELB"
  health_check_grace_period = var.asg_grace_period
  target_group_arns         = [aws_lb_target_group.tg.arn]

  launch_template {
    id      = aws_launch_template.lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "nodejs-instance"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Generate UUID for bucket name
resource "random_uuid" "bucket_uuid" {}

# Create S3 bucket
# This bucket will be used to store application data and other resources
# The bucket name is generated using a UUID to ensure uniqueness
resource "aws_s3_bucket" "bucket" {
  bucket = random_uuid.bucket_uuid.result

  force_destroy = true

  tags = {
    Name = "bucket"
  }
}

# The bucket is set to private.
# This configuration ensures that the bucket is not publicly accessible
resource "aws_s3_bucket_ownership_controls" "bucket_owner_control" {
  bucket = aws_s3_bucket.bucket.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# The bucket's public access is blocked
# This configuration ensures that the bucket does not allow public access
resource "aws_s3_bucket_public_access_block" "bucket_block_public_access" {
  bucket                  = aws_s3_bucket.bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# The bucket is encrypted with AES256.
resource "aws_s3_bucket_server_side_encryption_configuration" "bucket_encryption" {
  bucket = aws_s3_bucket.bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# The bucket has a lifecycle rule to transition objects to the STANDARD_IA storage class after 30 days.
resource "aws_s3_bucket_lifecycle_configuration" "bucket_lifecycle_rule" {
  bucket = aws_s3_bucket.bucket.id

  rule {
    id     = "transition-to-ia"
    status = "Enabled"

    filter {}

    transition {
      days          = var.s3_transition_days
      storage_class = var.s3_transition_storage_class
    }
  }
}