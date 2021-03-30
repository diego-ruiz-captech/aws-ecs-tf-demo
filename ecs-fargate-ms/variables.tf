variable "cluster_name" {
  description = "The ECS cluster name"
  type        = string
  default = "ecs-fargate-ms-demo"
}

variable "aws_region" {
  description = "The aws region"
  type        = string
  default = "us-east-1"
}

variable "aws_profile" {
  description = "The aws profile"
  type        = string
  default = "aws.demo"
}

variable "github_token" {
  description = "github token"
  type        = string
  sensitive   = true
}