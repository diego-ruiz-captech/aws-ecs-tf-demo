variable "name" {
  description = "The module instance name"
  type        = string
}

variable "cluster_id" {
  description = "The ECS cluster ID"
  type        = string
}

variable "cluster_name" {
  description = "The ECS cluster name"
  type        = string
}

variable "cluster_sg" {
  description = "The fargate instance security groups"
  type        = list(string)
}

variable "cluster_subnets" {
  description = "The ECS cluster public subnets"
  type        = list(string)
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
}

variable "github_owner" {
  description = "github owner"
  type        = string
}

variable "github_repo" {
  description = "github repo"
  type        = string
}

variable "github_branch" {
  description = "github branch"
  type        = string
}

variable "vpc_id" {
  description = "VPC id"
  type        = string
}