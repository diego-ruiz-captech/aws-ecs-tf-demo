
locals {
  name        = var.name
  github_owner = var.github_owner
  github_repo = var.github_repo
  github_branch = var.github_branch
}

# ECS task cloudwatch logs
resource "aws_cloudwatch_log_group" "api_demo" {
  name              = "${aws_ecr_repository.api.name}-logs"
  retention_in_days = 1
}

# ECS task execution role
data "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"
}

resource "aws_iam_policy" "policy_one" {
  name = "${aws_ecr_repository.api.name}-policy-demo1"

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        "Resource": "*"
      }
    ]
  })
}

resource "aws_iam_policy" "policy_two" {
  name = "${aws_ecr_repository.api.name}-policy-demo2"

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "secretsmanager:GetSecretValue",
          "ssm:GetParameters",
          "kms:Decrypt",
          "codedeploy:*"
        ],
        "Resource": "*"
      }
    ]
  })
}

resource "aws_iam_role" "api_demo_iam_role" {
  name = "${aws_ecr_repository.api.name}_ecsTaskExecutionRole"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      },
    ]
  })

  managed_policy_arns = [aws_iam_policy.policy_one.arn, aws_iam_policy.policy_two.arn]
}

# ECS simple task definition, this will be replaced by task definitions in deployment (ecs service requires one)
resource "aws_ecs_task_definition" "api_demo" {
  family = "${aws_ecr_repository.api.name}-hello"
  requires_compatibilities = ["FARGATE"]
  cpu = 512
  memory = 1024
  network_mode = "awsvpc"
  execution_role_arn       = aws_iam_role.api_demo_iam_role.arn
  container_definitions = <<EOF
[
  {
    "name": "api_demo",
    "image": "nginx:latest",
    "cpu": 512,
    "memory": 800,
    "portMappings": [
        {
          "containerPort": 8080,
          "hostPort": 8080
        }
    ]
  }
]
EOF

  lifecycle {
    ignore_changes = [container_definitions,family]
  }
}

resource "aws_ecs_service" "api_demo" {
  name            = "${aws_ecr_repository.api.name}-service"
  cluster         = var.cluster_id
  task_definition = aws_ecs_task_definition.api_demo.arn

  desired_count = 1

  deployment_maximum_percent         = 100
  deployment_minimum_healthy_percent = 0

  network_configuration {
      subnets = var.cluster_subnets
      security_groups = var.cluster_sg
      assign_public_ip = true
  }

  deployment_controller{
    type = "CODE_DEPLOY"
  }

  load_balancer {
    target_group_arn = module.alb.target_group_arns[0]
    container_name   = "api_demo"
    container_port   = 8080
  }

  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight = 1
  }

  lifecycle {
    ignore_changes = [load_balancer, task_definition]
  }
}

#----- ECR Repository ---------

resource "aws_ecr_repository" "api" {
  name                 = "${local.name}-api"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}


#----- code deploy ---------

resource "aws_iam_role" "codedeploy" {
  name = "${local.name}-codedeploy-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codedeploy.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "AWSCodeDeployRole" {
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeDeployRoleForECS"
  role       = aws_iam_role.codedeploy.name
}

resource "aws_codedeploy_app" "demo_api" {
  compute_platform = "ECS"
  name             = "${local.name}-api-deploy-app"
}

resource "aws_codedeploy_deployment_group" "demo_api" {
  app_name               = aws_codedeploy_app.demo_api.name
  deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"
  deployment_group_name  = "${local.name}-cd-dg"
  service_role_arn       = aws_iam_role.codedeploy.arn

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }

  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }

    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 3
    }
  }

  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }

  ecs_service {
    cluster_name = var.cluster_name
    service_name = aws_ecs_service.api_demo.name
  }

  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [module.alb.http_tcp_listener_arns[0]]
      }

      target_group {
        name = module.alb.target_group_names[0]
      }

      target_group {
        name = module.alb.target_group_names[1]
      }
    }
  }
}

#----- code pipeline --------
resource "aws_codepipeline" "codepipeline" {
  name     = "${local.name}-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.codepipeline_bucket.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner = "ThirdParty"
      provider = "GitHub"
      # owner            = "AWS"
      # provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        OAuthToken = "${var.github_token}"
        Owner = "${local.github_owner}"
        Repo = "${local.github_repo}"
        Branch = "${local.github_branch}"
      }

      # configuration = {
      #   ConnectionArn    = aws_codestarconnections_connection.example.arn
      #   FullRepositoryId = "diego-ruiz-captech/api-demo-app"
      #   BranchName       = "master"
      # }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.codebuild_api.name
      }
    }
  }
  
  stage {
    name = "Deploy"

    action {
      name = "ExternalDeploy"
      category = "Deploy"
      owner = "AWS"
      provider = "CodeDeployToECS"
      input_artifacts = ["build_output"]
      version = "1"

      configuration = {
        ApplicationName = aws_codedeploy_app.demo_api.name
        DeploymentGroupName = aws_codedeploy_deployment_group.demo_api.deployment_group_name
        TaskDefinitionTemplateArtifact = "build_output"
        TaskDefinitionTemplatePath = "taskdef.json"
        AppSpecTemplateArtifact = "build_output"
        AppSpecTemplatePath = "appspec.yml"
      }
    }
  }
}

resource "aws_codestarconnections_connection" "example" {
  name          = "${local.name}"
  provider_type = "GitHub"
}

resource "aws_s3_bucket" "codepipeline_bucket" {
  bucket = "${local.name}-api-pipeline-bucket"
  acl    = "private"
  force_destroy = true # demo purposes only
}

resource "aws_iam_role" "codepipeline_role" {
  name = "${local.name}-cp-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codepipeline.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "codepipeline_policy" {
  name = "${local.name}-cp-policy"
  role = aws_iam_role.codepipeline_role.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect":"Allow",
      "Action": [
        "s3:*"
      ],
      "Resource": [
        "${aws_s3_bucket.codepipeline_bucket.arn}",
        "${aws_s3_bucket.codepipeline_bucket.arn}/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "codedeploy:*",
        "ecs:RegisterTaskDefinition",
        "iam:PassRole"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "codebuild:BatchGetBuilds",
        "codebuild:StartBuild"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "codestar-connections:CreateConnection",
        "codestar-connections:DeleteConnection",
        "codestar-connections:GetConnection",
        "codestar-connections:ListConnections",
        "codestar-connections:GetInstallationUrl",
        "codestar-connections:GetIndividualAccessToken",
        "codestar-connections:ListInstallationTargets",
        "codestar-connections:StartOAuthHandshake",
        "codestar-connections:UpdateConnectionInstallation",
        "codestar-connections:UseConnection"
      ],
      "Resource": "${aws_codestarconnections_connection.example.arn}"
    }
  ]
}
EOF
}

data "aws_caller_identity" "current" {}

resource "aws_codebuild_project" "codebuild_api" {
  name           = "${local.name}-codebuild-api-demo"
  description    = "codebuild_api_demo"
  build_timeout  = "5"
  queued_timeout = "5"
  service_role  = aws_iam_role.codebuild.arn
  artifacts {
    type = "CODEPIPELINE"
  }

  # cache {
  #   type     = "S3"
  #   location = aws_s3_bucket.example.bucket
  # }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:3.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode = true

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.aws_region
    }

    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = data.aws_caller_identity.current.account_id
    }

    environment_variable {
      name  = "IMAGE_REPO_NAME"
      value = aws_ecr_repository.api.name
    }

    environment_variable {
      name  = "IMAGE_TAG"
      value = "latest"
    }

    environment_variable {
      name  = "MEMORY_RESV"
      value = 1024
    }

    environment_variable {
      name  = "SERVICE_PORT"
      value = 8080
    }

    environment_variable {
      name  = "APP_BUCKET_NAME"
      value = aws_s3_bucket.api_demo_bucket.id
    }

    environment_variable {
      name  = "AWS_ACCESS_KEY_ID_ARN"
      value = aws_ssm_parameter.api_access_key.arn
    }

    environment_variable {
      name  = "AWS_SECRET_ACCESS_KEY_ARN"
      value = aws_ssm_parameter.api_secret_key.arn
    }
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "log-group"
      stream_name = "log-stream"
    }

    # s3_logs {
    #   status   = "ENABLED"
    #   location = "${aws_s3_bucket.example.id}/build-log"
    # }
  }

  source {
    type = "CODEPIPELINE"
  }

  #source_version = "master"

  # vpc_config {
  #   vpc_id = module.vpc.vpc_id

  #   subnets = module.vpc.public_subnets

  #   # security_group_ids = [
  #   #   aws_security_group.example1.id,
  #   #   aws_security_group.example2.id,
  #   # ]
  # }
}

resource "aws_iam_role" "codebuild" {
  name = "${local.name}-codebuild-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "codebuild" {
  role = aws_iam_role.codebuild.name

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect":"Allow",
      "Action": [
        "s3:*"
      ],
      "Resource": [
        "${aws_s3_bucket.codepipeline_bucket.arn}",
        "${aws_s3_bucket.codepipeline_bucket.arn}/*"
      ]
    },
    {
      "Effect":"Allow",
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:CompleteLayerUpload",
        "ecr:GetAuthorizationToken",
        "ecr:InitiateLayerUpload",
        "ecr:PutImage",
        "ecr:UploadLayerPart"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Resource": [
        "*"
      ],
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateNetworkInterface",
        "ec2:DescribeDhcpOptions",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DeleteNetworkInterface",
        "ec2:DescribeSubnets",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeVpcs"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateNetworkInterfacePermission"
      ],
      "Resource": [
        "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:network-interface/*"
      ],
      "Condition": {
        "StringEquals": {
          "ec2:AuthorizedService": "codebuild.amazonaws.com"
        }
      }
    }
  ]
}
POLICY
}

resource "aws_s3_bucket" "api_demo_bucket" {
  bucket = "${local.name}-api-demo-bucket"
  acl    = "private"
  force_destroy = true # demo purposes only
}

# ----- api iam user -----
# this works but the access/secret keys are stored in plaintext of terraform state
resource "aws_iam_user" "api_demo_service" {
  name = "${local.name}-api-demo-service"
  path = "/system/"
}

resource "aws_iam_access_key" "api_demo_service_access_key" {
  user = aws_iam_user.api_demo_service.name
}

resource "aws_iam_user_policy" "api_demo_service_up" {
  name = "${local.name}-api_demo_service_up"
  user = aws_iam_user.api_demo_service.name

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:*"
      ],
      "Effect": "Allow",
      "Resource": [
        "${aws_s3_bucket.api_demo_bucket.arn}",
        "${aws_s3_bucket.api_demo_bucket.arn}/*"
      ]
    }
  ]
}
EOF
}

resource "aws_ssm_parameter" "api_access_key" {
  name        = "/develop/${local.name}/access_key/master"
  description = "The parameter description"
  type        = "SecureString"
  value       = aws_iam_access_key.api_demo_service_access_key.id
  tags = {
    environment = "develop"
  }
}

resource "aws_ssm_parameter" "api_secret_key" {
  name        = "/develop/${local.name}/secret_key/master"
  description = "The parameter description"
  type        = "SecureString"
  value       = aws_iam_access_key.api_demo_service_access_key.secret
  tags = {
    environment = "develop"
  }
}

# ----- application load balancer --------

module "alb_security_group" {
  source              = "terraform-aws-modules/security-group/aws"
  version             = "~> 3.0"

  name                = "${local.name}-alb-ms-sg"
  description         = "Security group for example usage with ALB"
  vpc_id              = var.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["http-80-tcp", "https-443-tcp"]
  ingress_with_cidr_blocks = [
    {
      from_port   = 3000
      to_port     = 3000
      protocol    = "tcp"
      description = "User-service ports"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
  egress_rules        = ["all-all"]
}

module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 5.0"

  name = "${var.name}"

  load_balancer_type = "application"

  vpc_id             = var.vpc_id
  subnets            = var.cluster_subnets.*
  security_groups    = [module.alb_security_group.this_security_group_id]

  # access_logs = {
  #   bucket = "my-alb-logs"
  # }

  target_groups = [
    {
      name_prefix      = "pref-"
      backend_protocol = "HTTP"
      backend_port     = 8080
      target_type      = "ip"
    },
    {
      name_prefix      = "pref-"
      backend_protocol = "HTTP"
      backend_port     = 8080
      target_type      = "ip"
    }
  ]

  # https_listeners = [
  #   {
  #     port               = 443
  #     protocol           = "HTTPS"
  #     certificate_arn    = aws_acm_certificate.cert.arn
  #     target_group_index = 0
  #   }
  # ]

  http_tcp_listeners = [
    {
      port               = 80
      protocol           = "HTTP"
      target_group_index = 0
    }
  ]

  # https_listener_rules = [
  #   {
  #     https_listener_index = 0
  #     priority             = 2

  #     actions = [{
  #       type        = "forward"
  #       target_group_index = 0
  #     }]

  #     conditions = [{
  #       path_patterns = ["/api-demo"]
  #     }]
  #   }
  # ]

  tags = {
    Environment = "develop"
  }
}