provider "aws" {
  region = "us-east-1"
}

# --- Create SQS Queue ---
resource "aws_sqs_queue" "email_queue" {
  name = "email-queue"
}

# --- Create SSM Parameter (token) ---
resource "aws_ssm_parameter" "auth_token" {
  name  = "/auth/token"
  type  = "SecureString"
  value = "$DJISA<$#45ex3RtYr"
}

resource "aws_s3_bucket" "microservice_data" {
  bucket = "microservice-data"
}

# --------------------------
# VPC MODULE - creates a basic VPC with public subnets and internet gateway
# --------------------------
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = ">= 3.0"

  name = "simple-vpc"           # Friendly name for the VPC and related resources
  cidr = "10.0.0.0/16"          # IP range for the VPC

  azs             = ["us-east-1a", "us-east-1b"] # Availability zones for subnets
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"] # Subnets open to the internet

  enable_nat_gateway = false   # No NAT gateway needed as we only have public subnets
  enable_dns_hostnames = true  # Needed for ECS to resolve hostnames
}

# --------------------------
# ECS CLUSTER - logical grouping of ECS tasks/services
# --------------------------
resource "aws_ecs_cluster" "main" {
  name = "simple-ecs-cluster"  # Name of the ECS cluster
}

# --------------------------
# SECURITY GROUP - allows inbound traffic to the ELB on port 80 (HTTP)
# --------------------------
resource "aws_security_group" "elb_sg" {
  name        = "elb-sg"
  description = "Allow HTTP inbound to ELB"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description      = "HTTP from anywhere"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"] 
  }

  egress {
    description      = "Allow all outbound traffic"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }
}

# --------------------------
# CLASSIC ELB - load balances traffic to ECS tasks
# --------------------------
resource "aws_elb" "main" {
  name               = "simple-elb"
  internal           = false                  # Internet-facing ELB
  security_groups    = [aws_security_group.elb_sg.id]
  subnets            = module.vpc.public_subnets

  listener {
    instance_port     = 80                      # Port on ECS task/container
    instance_protocol = "http"
    lb_port           = 80                      # Port on the ELB
    lb_protocol       = "http"
  }

  cross_zone_load_balancing = true               # Distribute load evenly across AZs
  idle_timeout               = 60                 # Connection idle timeout in seconds

  tags = {
    Name = "simple-elb"
  }
}

# --------------------------
# TASK DEFINITION - defines container specs for ECS
# --------------------------
resource "aws_ecs_task_definition" "simple_task" {
  family                   = "simple-task"               # Task family name
  network_mode             = "bridge"                    # Docker default networking mode
  requires_compatibilities = ["EC2"]                     # EC2 launch type (not Fargate)

  container_definitions = jsonencode([
    {
      name      = "api"                               # Container name
      image     = "er92442/api:latest"                        # Container image (NGINX server)
      essential = true                                  # Mark as essential container

      memory    = 256 
      cpu       = 256                                   # CPU units for the container

      portMappings = [
        {
          containerPort = 80                             # Port inside container
          hostPort      = 80                             # Port on EC2 instance (same as ELB instance port)
          protocol      = "tcp"
        }
      ]
    }
  ])
}

# --------------------------
# ECS SERVICE - runs and manages the task behind ELB
# --------------------------
resource "aws_ecs_service" "simple_service" {
  name            = "simple-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.simple_task.arn
  desired_count   = 1                              # Number of tasks to run

  launch_type     = "EC2"                          # Use EC2 launch (not Fargate)
  
  load_balancer {
    elb_name        = aws_elb.main.name           # Attach ECS service to ELB
    container_name  = "api"                      # Container name in task definition
    container_port  = 80                           # Port to route traffic
  }

  deployment_minimum_healthy_percent = 50         # Minimum healthy during deployment
  deployment_maximum_percent         = 200        # Max percentage during deployment

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [ 
    aws_ecs_task_definition.simple_task
  ]
   

  # ECS service must be in subnets that the ELB targets via EC2 instances
  # Here, instances need to be in the VPC public subnets to receive traffic from ELB
}

# --------------------------
# NOTE: ECS EC2 Instances (ECS Container Instances)
# --------------------------
# This example assumes you already have or will manually launch EC2 instances with ECS agent
# registered to the cluster in the public subnets (with security group allowing inbound from ELB).
# For simplicity, this example does not automate EC2 instances or autoscaling group.


