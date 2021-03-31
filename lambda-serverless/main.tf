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
  name        = var.lambda_name
  db_name     = "demo_db"
  environment = "dev"
}

resource "random_string" "password" {
  length  = 16
  special = false
}

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

module "rds_sg" {
  source              = "terraform-aws-modules/security-group/aws"
  version             = "~> 3.0"

  name                = "${local.name}-rds-sg"
  description         = "Security group for RDS instances"
  vpc_id              = module.vpc.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["all-icmp", "ssh-tcp", "mysql-tcp"]
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

resource "aws_db_instance" "default" {
  allocated_storage    = 10
  engine               = "mysql"
  engine_version       = "5.7"
  name                   = local.db_name
  username               = "demo_user"
  password               = "${random_string.password.result}"
  instance_class       = "db.t3.micro"
  parameter_group_name   = "default.mysql5.7"
  skip_final_snapshot   = true
  db_subnet_group_name = module.vpc.database_subnet_group_name
  vpc_security_group_ids = [module.rds_sg.this_security_group_id]
}

data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 2.0"

  name = local.name

  cidr = "10.1.0.0/16"

  azs             = [data.aws_availability_zones.available.names[0], data.aws_availability_zones.available.names[1]]
  database_subnets = ["10.1.1.0/24", "10.1.2.0/24"]
  public_subnets  = ["10.1.11.0/24", "10.1.12.0/24"]

  enable_nat_gateway = false # false is just faster

  tags = {
    Environment = local.environment
    Name        = local.name
  }
}

resource "aws_ssm_parameter" "endpoint" {
  name        = "/database/${local.db_name}/endpoint"
  description = "Endpoint to connect to the ${local.db_name} database"
  type        = "SecureString"
  value       = "${aws_db_instance.default.address}"
}

resource "aws_ssm_parameter" "name" {
  name        = "/database/${local.db_name}/name"
  description = "DB Name to connect to the ${local.db_name} database"
  type        = "SecureString"
  value       = "${aws_db_instance.default.name}"
}

resource "aws_ssm_parameter" "user" {
  name        = "/database/${local.db_name}/user"
  description = "DB User to connect to the ${local.db_name} database"
  type        = "SecureString"
  value       = "${aws_db_instance.default.username}"
}

resource "aws_ssm_parameter" "password" {
  name        = "/database/${local.db_name}/password"
  description = "DB Pass to connect to the ${local.db_name} database"
  type        = "SecureString"
  value       = "${aws_db_instance.default.password}"
}

resource "aws_ssm_parameter" "vpc_subnet_ids" {
  name        = "/database/${local.db_name}/subnet_ids"
  description = "Lambda exec - DB subnets to connect to the ${local.db_name} database"
  type        = "StringList"
  value       = "${join(",", module.vpc.database_subnets.*)}"
}

resource "aws_ssm_parameter" "lambda_sg" {
  name        = "/database/${local.db_name}/lambda_sg"
  description = "Lambda exec - security group to connect to the ${local.db_name} database"
  type        = "String"
  value       = "${module.lambda_exec_sg.this_security_group_id}"
}

module "bastion_sg" {
  source              = "terraform-aws-modules/security-group/aws"
  version             = "~> 3.0"

  name                = "${local.name}-bastion-asg"
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

module "lambda_exec_sg" {
  source              = "terraform-aws-modules/security-group/aws"
  version             = "~> 3.0"

  name                = "${local.name}-lambda-exec-role"
  description         = "Security group for lambda exe"
  vpc_id              = module.vpc.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
#   ingress_rules       = ["all-all"]
  ingress_rules       = ["http-80-tcp", "all-icmp", "ssh-tcp", "mysql-tcp"]
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

# ec2 base image for Bastion
data "aws_ami" "amazon_linux" {
  most_recent = true

  owners = ["amazon"]

  filter {
    name = "name"

    values = [
      "amzn-ami-hvm-*-x86_64-gp2"
    ]
  }

  filter {
    name = "owner-alias"

    values = [
      "amazon"
    ]
  }
}

# ----- Bastion ---------
module "ec2-instance" {
  
  source                  = "terraform-aws-modules/ec2-instance/aws"
  version                 = "2.17.0"
  
  # insert the 10 required variables here
  instance_count          = 1
  name                    = "${local.name}-bastion-ec2"
  ami                     = data.aws_ami.amazon_linux.id
  instance_type           = "t2.micro"
  vpc_security_group_ids  = [module.bastion_sg.this_security_group_id]
  
  subnet_id               = module.vpc.public_subnets[0]
  key_name                = "demo-lambda-ssh-key"
  
}

resource "null_resource" "update_bastion" {
  depends_on = [
    module.ec2-instance,
    local_file.bastion_key
  ]

  provisioner "remote-exec" {
    inline = [
      "sudo yum -y update",
      "sudo yum -y install mysql57"
    ]
    connection {
      host = module.ec2-instance.public_ip[0]
      type        = "ssh"
      user        = "ec2-user"
      private_key = file(local_file.bastion_key.filename)
    }
  }
}

# setup ssh connection to ec2 instances
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key" {
  key_name   = "demo-lambda-ssh-key"
  public_key = tls_private_key.ssh.public_key_openssh
}

resource "local_file" "bastion_key" {
    sensitive_content = tls_private_key.ssh.private_key_pem
    filename = "${path.module}/ec2_private_key_pem"
    file_permission = "0600"
}

# Proof of concept that terraform can create lambda functions too

resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_lambda_function" "test_lambda" {
  #filename      = "lambda_function_payload.zip"
  function_name = "${local.name}-terraform-lambda-example"
  role          = aws_iam_role.iam_for_lambda.arn
  
  image_uri = "amazon/aws-lambda-nodejs"
  runtime = "nodejs12.x"

  
}