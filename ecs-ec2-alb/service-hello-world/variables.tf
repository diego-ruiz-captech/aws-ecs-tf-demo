variable "cluster_id" {
  description = "The ECS cluster ID"
  type        = string
}

variable "aws_lb_target_group"{
  description = "AWS LB target group"
  type        = string
}

variable "capacity_provider_name" {
  description = "ECS Capacity provider name"
  type        = string
}