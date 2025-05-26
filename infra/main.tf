provider "aws" {
  region = "us-east-1"
}

resource "aws_sqs_queue" "email_queue" {
  name = "email-queue"
}

resource "aws_ssm_parameter" "auth_token" {
  name  = "/auth/token"
  type  = "SecureString"
  value = "$DJISA<$#45ex3RtYr"
}

resource "aws_s3_bucket" "microservice_data" {
  bucket = "microservice-data"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = ">= 5.0"

  name = "simple-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a" , "us-east-1b"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]

  enable_nat_gateway = false
  enable_vpn_gateway = false
  create_igw = true 
  
  enable_dns_hostnames = true
  enable_dns_support = true
  map_public_ip_on_launch = true
  
}

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

resource "aws_security_group" "ecs_sg" {
  name        = "ecs-instance-sg"
  description = "Allow traffic from ELB"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "Allow traffic from ELB on port 8000"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    security_groups = [aws_security_group.elb_sg.id]
  }

  ingress {
    description = "Allow traffic from ELB on port 80"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = [aws_security_group.elb_sg.id]
  }

  ingress {
    description = "Allow traffic from ELB on port 443"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    security_groups = [aws_security_group.elb_sg.id]
  }

  # ADD: Allow HTTPS outbound for Docker Hub, ECR, SSM
  egress {
    description = "HTTPS outbound"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # ADD: Allow HTTP outbound
  egress {
    description = "HTTP outbound"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_elb" "main" {
  name               = "simple-elb"
  internal           = false
  security_groups    = [aws_security_group.elb_sg.id]
  subnets            = module.vpc.public_subnets

  listener {
    instance_port     = 8000
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    target              = "HTTP:8000/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  cross_zone_load_balancing = true
  idle_timeout               = 60

  tags = {
    Name = "simple-elb"
  }
}

module "ecs_cluster" {
  source = "terraform-aws-modules/ecs/aws"
  cluster_name = "my-app"
  default_capacity_provider_use_fargate = false

  autoscaling_capacity_providers = {
    ex_1 = {
      auto_scaling_group_arn         = module.autoscaling["ex_1"].autoscaling_group_arn
      managed_scaling = {
        maximum_scaling_step_size = 5
        minimum_scaling_step_size = 1
        status                    = "ENABLED"
        target_capacity           = 60
      }
    }
  }

  services = {
    api = {
      name = "api"
      desired_count   = 1
      launch_type     = "EC2" 
      network_mode    = "bridge"
      requires_compatibilities = ["EC2"] 
       
      capacity_provider_strategy = [
      {
        capacity_provider = "ex_1"
        weight            = 1
      }
      ]
      container_definitions = {
        api = {
          network_mode = "bridge"
          image     = "er92442/api:latest"
          essential = true
          port_mappings = [
            {
              name          = "api"
              containerPort = 8000
              hostPort      = 8000
              protocol      = "tcp"
            }
          ]
          enable_cloudwatch_logging = true
        }
      }
      load_balancer = {
        service = {
          container_name   = "api"
          container_port   = 8000
          elb_name         = aws_elb.main.name
        }
      }
      subnet_ids = module.vpc.public_subnets
    }
  }
}

module "autoscaling" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "~> 8.0"
  for_each = {
    ex_1 = {
      instance_type              = "t3.micro"
      use_mixed_instances_policy = false
      mixed_instances_policy     = {}
    }
  }
  name = "autoscaling-group-${each.key}"
  image_id = data.aws_ssm_parameter.ecs_ami.value
  instance_type = each.value.instance_type
  vpc_zone_identifier = module.vpc.public_subnets
  health_check_type   = "EC2"
  min_size            = 1
  max_size            = 1
  desired_capacity    = 1

  create_iam_instance_profile = true
  iam_role_name               = "ecs-instance-role-${each.key}"
  
  # FIXED: Proper user data with better ECS config
  user_data = base64encode(<<-EOF
    #!/bin/bash
    echo ECS_CLUSTER=my-app >> /etc/ecs/ecs.config
    echo ECS_ENABLE_TASK_IAM_ROLE=true >> /etc/ecs/ecs.config
    echo ECS_ENABLE_CONTAINER_METADATA=true >> /etc/ecs/ecs.config
    systemctl restart ecs
    yum update -y
    EOF
  )
  
  iam_role_policies = {
    AmazonEC2ContainerServiceforEC2Role = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
    AmazonSSMManagedInstanceCore        = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    AmazonS3FullAccess                  = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
    AmazonSQSFullAccess                 = "arn:aws:iam::aws:policy/AmazonSQSFullAccess"
    SecretsManagerReadWrite             = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
  }
  
  network_interfaces = [
    {
      delete_on_termination       = true
      device_index                = 0
      associate_public_ip_address = true
      security_groups             = [aws_security_group.ecs_sg.id]
    }
  ]
}

data "aws_ssm_parameter" "ecs_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
}