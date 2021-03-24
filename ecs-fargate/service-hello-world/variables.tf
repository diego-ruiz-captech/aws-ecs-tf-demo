variable "cluster_id" {
  description = "The ECS cluster ID"
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