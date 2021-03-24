resource "aws_cloudwatch_log_group" "hello_world" {
  name              = "hello_world"
  retention_in_days = 1
}


resource "aws_ecs_task_definition" "hello_world" {
  family = "hello_world"

  container_definitions = <<EOF
[
  {
    "name": "hello_world",
    "image": "nginxdemos/hello",
    "cpu": 512,
    "memory": 256,
    "portMappings": [
        {
          "containerPort": 80,
          "hostPort": 80
        }
    ],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-region": "us-east-1",
        "awslogs-group": "hello_world",
        "awslogs-stream-prefix": "complete-ecs"
      }
    }
  }
]
EOF
}

resource "aws_ecs_service" "hello_world" {
  name            = "hello_world"
  cluster         = var.cluster_id
  task_definition = aws_ecs_task_definition.hello_world.arn
  
#   iam_role        = aws_iam_role.svc.arn

  desired_count = 1

  deployment_maximum_percent         = 100
  deployment_minimum_healthy_percent = 0

  load_balancer {
    target_group_arn = var.aws_lb_target_group
    container_name   = "hello_world"
    container_port   = 80
  }

  capacity_provider_strategy {
    capacity_provider = var.capacity_provider_name
    weight = 1
  }
}

# resource "aws_iam_role" "svc" {
#   name = "test-ecs-role"

#   assume_role_policy = <<EOF
# {
#   "Version": "2008-10-17",
#   "Statement": [
# 	{
# 	  "Sid": "",
# 	  "Effect": "Allow",
# 	  "Principal": {
# 		"Service": "ecs.amazonaws.com"
# 	  },
# 	  "Action": "sts:AssumeRole"
# 	}
#   ]
# }
# EOF
# }

# resource "aws_iam_role_policy_attachment" "svc" {
#   role       = "${aws_iam_role.svc.name}"
#   policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceRole"
# }