variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "backend_image" {
  description = "Docker image for the backend service"
  type        = string
  default     = "er92442/backend:latest"
}
variable "api_image" {
  description = "Docker image for the API service"
  type        = string
  default     = "er92442/api:latest"
}

variable "auth_token" {
  description = "Authentication token for the API"
  type        = string
  default     = "$DJISA<$#45ex3RtYr"
}

variable "bucket_name" {
  description = "S3 bucket name for storing files"
  type        = string
  default     = "microservice_data"
}
variable "queue_name" {
  description = "SQS queue name for email processing"
  type        = string
  default     = "email-queue"
  
}

variable "api_image_version" {
  description = "Version of the API Docker image"
  type        = string
  default     = "latest"
}
variable "backend_image_version" {
  description = "Version of the backend Docker image"
  type        = string
  default     = "latest"
}
