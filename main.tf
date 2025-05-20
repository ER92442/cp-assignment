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

# # --- IAM Role for EC2 Instance ---
# resource "aws_iam_role" "ec2_role" {
#   name = "ec2-microservice-role"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       {
#         Effect = "Allow",
#         Principal = {
#           Service = "ec2.amazonaws.com"
#         },
#         Action = "sts:AssumeRole"
#       }
#     ]
#   })
# }

# --- IAM Policy for EC2 to access SSM and SQS ---
# resource "aws_iam_policy" "ec2_policy" {
#   name = "ec2-access-ssm-sqs"

#   policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       {
#         Effect = "Allow",
#         Action = [
#           "ssm:GetParameter",
#           "sqs:SendMessage"
#         ],
#         Resource = "*"
#       }
#     ]
#   })
# }

# --- Attach the policy to the IAM role ---
# resource "aws_iam_role_policy_attachment" "ec2_policy_attach" {
#   role       = aws_iam_role.ec2_role.name
#   policy_arn = aws_iam_policy.ec2_policy.arn
# }

# # --- IAM Instance Profile to attach to EC2 ---
# resource "aws_iam_instance_profile" "ec2_profile" {
#   name = "ec2-instance-profile"
#   role = aws_iam_role.ec2_role.name
# }

# --- Security Group to allow inbound HTTP traffic ---
# resource "aws_security_group" "microservice_sg" {
#   name        = "microservice-sg"
#   description = "Allow inbound access to FastAPI app"
#   vpc_id      = data.aws_vpc.default.id

#   ingress {
#     description = "Allow HTTP"
#     from_port   = 8000
#     to_port     = 8000
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
# }

# --- Find default VPC and subnet (for simplicity) ---
# data "aws_vpc" "default" {
#   default = true
# }

# data "aws_subnet_ids" "default" {
#   vpc_id = data.aws_vpc.default.id
# }

# this is the AMI ID for Amazon Linux 2
# ami  is aws resource that is used to create EC2 instances
# data "aws_ami" "amazon_linux" {
#   most_recent = true
#   owners      = ["amazon"]

#   filter {
#     name   = "name"
#     values = ["amzn2-ami-hvm-*-x86_64-gp2"]
#   }
# }


