terraform {
  required_version = ">= 0.13"
  backend "s3" {
  }
}

provider "aws" {
  region = "us-east-1"
  profile = "aws.demo"
}

locals {
  name        = var.cluster_name
  environment = "dev"

  # This is the convention we use to know what belongs to each other
  ec2_resources_name = "${local.name}-${local.environment}"
}

resource "aws_secretsmanager_secret" "hello-world-dbpass" {
  name = "hello_world_db_password"
}

resource "aws_iam_policy" "ecs-secrets-manager-policy" {
  name = "CustomerManaged-ECS-SecretsManager"
  path = "/"
  policy = jsonencode (
  {
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "VisualEditor0"
        Effect =  "Allow"
        Action = [
          "secretsmanager:GetResourcePolicy",
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecretVersionIds"
        ]
        Resource = "${aws_secretsmanager_secret.hello-world-dbpass}"
      }
    ]
  })
}

resource "aws_iam_role" "ecs-task-exec-role" {
  name               = "CustomerManaged-ecsTaskExecutionRole"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "secrets-manager-ecs-attach" {
  role       = aws_iam_role.ecs-task-exec-role.name
  policy_arn = aws_iam_policy.ecs-secrets-manager-policy.arn
}

resource "aws_iam_role_policy_attachment" "ecs-exec-attach" {
  role       = aws_iam_role.ecs-task-exec-role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

output "ecs-exec-role-arn" {
  value = aws_iam_role.ecs-task-exec-role.arn
}

# # needed to set ports on ec2 instances
module "security_group" {
  source              = "terraform-aws-modules/security-group/aws"
  version             = "~> 3.0"

  name                = "${var.cluster_name}-sg"
  description         = "Security group for example usage with EC2 instance"
  vpc_id              = module.vpc.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["http-80-tcp", "all-icmp", "ssh-tcp"]
  ingress_with_cidr_blocks = [
    {
      from_port   = 32768
      to_port     = 65535
      protocol    = "tcp"
      description = "User-service ports"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
  egress_rules        = ["all-all"]
}

resource "aws_ecr_repository" "foo" {
  name                 = "tf-fargate-ecs-demo"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

#----- Network ------
data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 2.0"

  name = local.name

  cidr = "10.1.0.0/16"

  azs             = [data.aws_availability_zones.available.names[0], data.aws_availability_zones.available.names[1]]
  private_subnets = ["10.1.1.0/24", "10.1.2.0/24"]
  public_subnets  = ["10.1.11.0/24", "10.1.12.0/24"]

  enable_nat_gateway = false # false is just faster

  tags = {
    Environment = local.environment
    Name        = local.name
  }
}

#---- CloudWatch Group ------
resource "aws_cloudwatch_log_group" "ecs_hello_service" {
  name = "/ecs/hello-service"

  tags = {
    Environment = local.environment
    Application = "Hello-Service"
  }
}

#---- CloudWatch Metric ------
resource "aws_cloudwatch_log_metric_filter" "hello_service_error_filter" {
  name           = "hello_service_errors"
  pattern        = "Exception"
  log_group_name = aws_cloudwatch_log_group.ecs_hello_service.name

  metric_transformation {
    name      = "HelloErrorCount"
    namespace = "ecs_hello"
    value     = "1"
  }
}

#---- CloudWatch Metric Alarm ------
resource "aws_cloudwatch_metric_alarm" "hello_service_error_alarm" {
  alarm_name                = "Hello Service Exceptions"
  alarm_description         = "Alarm is triggered when there are 2 or more exceptions in an hour."
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  period                    = "3600"
  statistic                 = "Average"
  threshold                 = "2"
  insufficient_data_actions = []

  metric_name               = aws_cloudwatch_log_metric_filter.hello_service_error_filter.metric_transformation[0].name
  namespace                 = aws_cloudwatch_log_metric_filter.hello_service_error_filter.metric_transformation[0].namespace

  #alarm_actions             = [aws_sns_topic.some_topic_that_triggers_a_lambda]
  #ok_actions                = [aws_sns_topic.some_topic_that_triggers_another_lambda]
}

#----- ECS --------
module "ecs" {
  source = "terraform-aws-modules/ecs/aws"

  depends_on = [
    module.vpc,
  ]

  name               = local.name
  container_insights = true

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy = [{
    capacity_provider = "FARGATE_SPOT"
    weight            = "1"
  }]

  tags = {
    Environment = local.environment
  }
}

#----- ECS  Services--------
module "hello_world" {
  source = "./service-hello-world"

  cluster_id = module.ecs.this_ecs_cluster_id
  cluster_sg = [module.security_group.this_security_group_id]
  cluster_subnets = module.vpc.public_subnets
  task_exec_role_arn = aws_iam_role.ecs-task-exec-role.arn
}
