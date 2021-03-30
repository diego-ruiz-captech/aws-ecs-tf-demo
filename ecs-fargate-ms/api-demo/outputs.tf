output "aws_ecs_service_name" {
    value = aws_ecs_service.api_demo.name
}

output "aws_ecs_service_role" {
    value = aws_iam_role.api_demo_iam_role.arn
}

output "alb_dns" {
  value = module.alb.this_lb_dns_name
}