resource "aws_cloudwatch_log_group" "hello_world" {
  name              = "hello_world"
  retention_in_days = 1
}

# data "aws_iam_role" "ecs_task_execution_role" {
#   name = "ecsTaskExecutionRole"
# }

resource "aws_ecs_task_definition" "hello_world" {
  family = "hello_world"
  requires_compatibilities = ["FARGATE"]
  cpu = 512
  memory = 1024
  network_mode = "awsvpc"
  task_role_arn            = var.task_exec_role_arn
  execution_role_arn       = var.task_exec_role_arn
  container_definitions = jsonencode (
  [
    {
      name   = "hello_world"
      image  = "nginxdemos/hello"
      cpu    = 512
      memory = 256
      portMappings = [
          {
            containerPort = 80,
            hostPort      = 80
          }
      ],
      secrets= [
        {
          name = "HELLO_DB_PASS",
          value = var.hello_dbpass_arn
        }
      ]
    }
  ]
)
}

resource "aws_ecs_service" "hello_world" {
  name            = "hello_world"
  cluster         = var.cluster_id
  task_definition = aws_ecs_task_definition.hello_world.arn

  desired_count = 1

  deployment_maximum_percent         = 100
  deployment_minimum_healthy_percent = 0

  network_configuration {
      subnets = var.cluster_subnets
      security_groups = var.cluster_sg
      assign_public_ip = true
  }
}
