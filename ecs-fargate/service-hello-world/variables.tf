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

variable "task_exec_role_arn" {
  description = "The arn for the custom task exececution role"
  type        = string
}

variable "hello_dbpass_arn" {
  description = "The arn for the db password in ssm"
  type        = string
}
