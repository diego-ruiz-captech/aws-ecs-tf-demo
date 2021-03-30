terraform {
  required_version = ">= 0.13"
  backend "s3" {
  }
}

provider "aws" {
  region = var.aws_region
  profile = var.aws_profile
}

locals {
  name        = var.cluster_name
  environment = "dev"
  # api repo details - https://github.com/diego-ruiz-captech/api-demo-app
  github_owner = "diego-ruiz-captech"
  github_repo = "api-demo-app"
  github_branch = "master"
}

# needed to set ports on fargate instances
module "ecs_api_sg" {
  source              = "terraform-aws-modules/security-group/aws"
  version             = "~> 3.0"

  name                = "${local.name}-ecs-api-sg"
  description         = "Security group for ecs running tasks"
  vpc_id              = module.vpc.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["http-80-tcp", "all-icmp", "ssh-tcp", "http-8080-tcp"]
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

  enable_nat_gateway = true # false is just faster

  tags = {
    Environment = local.environment
    Name        = local.name
  }
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
module "api1_ecs" {
  source = "./api-demo"

  name = "${local.name}-api1"
  cluster_name = module.ecs.this_ecs_cluster_name
  cluster_id = module.ecs.this_ecs_cluster_id
  cluster_sg = [module.ecs_api_sg.this_security_group_id]
  cluster_subnets = module.vpc.public_subnets
  vpc_id = module.vpc.vpc_id
  github_token = var.github_token
  github_owner = local.github_owner
  github_repo = local.github_repo
  github_branch = local.github_branch
}
