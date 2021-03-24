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
  environment = "dev"

  # This is the convention we use to know what belongs to each other
  ec2_resources_name = "${var.cluster_name}-${local.environment}"
}

# ----- EC2 configurations -------

# needed to set ports on ec2 instances
module "security_group" {
  source              = "terraform-aws-modules/security-group/aws"
  version             = "~> 3.0"

  name                = "${var.cluster_name}-bastion-asg"
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

# ec2 base image for Bastion
data "aws_ami" "amazon_linux" {
  most_recent = true

  owners = ["amazon"]

  filter {
    name = "name"

    values = [
      "amzn-ami-hvm-*-x86_64-gp2",
    ]
  }

  filter {
    name = "owner-alias"

    values = [
      "amazon",
    ]
  }
}

# ----- Bastion ---------
module "ec2-instance" {
  source                  = "terraform-aws-modules/ec2-instance/aws"
  version                 = "2.17.0"
  # insert the 10 required variables here
  instance_count          = 1
  name                    = "${var.cluster_name}-bastion-ec2"
  ami                     = data.aws_ami.amazon_linux.id
  instance_type           = "t2.micro"
  vpc_security_group_ids  = [module.security_group.this_security_group_id]
  
  subnet_id               = module.vpc.public_subnets[0]
  key_name                = "demo-ssh-key"
}

# setup ssh connection to ec2 instances
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key" {
  key_name   = "demo-ssh-key"
  public_key = tls_private_key.ssh.public_key_openssh
}

# ----- ECR repository ------
# This would be used to deploy docker images in order to deploy to ECS cluster

resource "aws_ecr_repository" "foo" {
  name                 = "tf-demo"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "local_file" "bastion_key" {
    sensitive_content = tls_private_key.ssh.private_key_pem
    filename = "${path.module}/ec2_private_key_pem"
    file_permission = "0600"
}

# ----- application load balancer --------

module "alb_security_group" {
  source              = "terraform-aws-modules/security-group/aws"
  version             = "~> 3.0"

  name                = "${var.cluster_name}-alb-sg"
  description         = "Security group for example usage with ALB"
  vpc_id              = module.vpc.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["http-80-tcp", "https-443-tcp"]
  egress_rules        = ["all-all"]
}

module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 5.0"

  name = "my-alb"

  load_balancer_type = "application"

  vpc_id             = module.vpc.vpc_id
  subnets            = module.vpc.public_subnets.*
  security_groups    = [module.alb_security_group.this_security_group_id]

  # access_logs = {
  #   bucket = "my-alb-logs"
  # }

  target_groups = [
    {
      name_prefix      = "pref-"
      backend_protocol = "HTTP"
      backend_port     = 80
      target_type      = "instance"
    }
  ]

  # https_listeners = [
  #   {
  #     port               = 443
  #     protocol           = "HTTPS"
  #     certificate_arn    = "arn:aws:iam::123456789012:server-certificate/test_cert-123456789012"
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

  tags = {
    Environment = "Test"
  }
}

#----- Network ------

data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 2.0"

  name = var.cluster_name

  cidr = "10.1.0.0/16"

  azs             = [data.aws_availability_zones.available.names[0], data.aws_availability_zones.available.names[1]]
  private_subnets = ["10.1.1.0/24", "10.1.2.0/24"]
  public_subnets  = ["10.1.11.0/24", "10.1.12.0/24"]

  enable_nat_gateway = true # false is just faster

  tags = {
    Environment = local.environment
    Name        = var.cluster_name
  }
}

#----- ECS --------
# NOT USING Community module, there's a known teardown issue when dealing with Autoscaling groups
# https://github.com/hashicorp/terraform-provider-aws/issues/4852
#
# module "ecs" {
#   source = "terraform-aws-modules/ecs/aws"

#   depends_on = [
#     module.vpc,
#   ]

#   name               = var.cluster_name
#   container_insights = true

#   capacity_providers = ["FARGATE", "FARGATE_SPOT", aws_ecs_capacity_provider.prov1.name]

#   default_capacity_provider_strategy = [{
#     capacity_provider = aws_ecs_capacity_provider.prov1.name # "FARGATE_SPOT"
#     weight            = "1"
#   }]

#   tags = {
#     Environment = local.environment
#   }
# }

resource "aws_ecs_cluster" "this" {

  name = var.cluster_name

  capacity_providers = [aws_ecs_capacity_provider.prov1.name]
  #capacity_providers = ["FARGATE", "FARGATE_SPOT", aws_ecs_capacity_provider.prov1.name]

  dynamic "default_capacity_provider_strategy" {
    for_each = [{
      capacity_provider = aws_ecs_capacity_provider.prov1.name # "FARGATE_SPOT"
      weight            = "1"
    }]

    iterator = strategy

    content {
      capacity_provider = strategy.value["capacity_provider"]
      weight            = lookup(strategy.value, "weight", null)
      base              = lookup(strategy.value, "base", null)
    }
  }

  setting {
    name  = "containerInsights"
    value = "disabled"#var.container_insights ? "enabled" : "disabled"
  }

  tags = {
    Environment = local.environment
  }

  # pulled from https://github.com/hashicorp/terraform-provider-aws/issues/11409#issuecomment-568254554
  # to properly teardown ecs + asg, requires setting only single capacity provider
  provisioner "local-exec" {
    when = destroy

    command = <<CMD
      # Get the list of capacity providers associated with this cluster
      CAP_PROVS="$(aws ecs describe-clusters --profile aws.demo --clusters "${self.arn}" \
        --query 'clusters[*].capacityProviders[*]' --output text)"

      # Now get the list of autoscaling groups from those capacity providers
      ASG_ARNS="$(aws ecs describe-capacity-providers \
        --profile aws.demo \
        --capacity-providers "$CAP_PROVS" \
        --query 'capacityProviders[*].autoScalingGroupProvider.autoScalingGroupArn' \
        --output text)"

      if [ -n "$ASG_ARNS" ] && [ "$ASG_ARNS" != "None" ]
      then
        for ASG_ARN in $ASG_ARNS
        do
          ASG_NAME=$(echo $ASG_ARN | cut -d/ -f2-)

          # Set the autoscaling group size to zero
          aws autoscaling update-auto-scaling-group \
            --profile aws.demo \
            --auto-scaling-group-name "$ASG_NAME" \
            --min-size 0 --max-size 0 --desired-capacity 0

          # Remove scale-in protection from all instances in the asg
          INSTANCES="$(aws autoscaling describe-auto-scaling-groups \
            --profile aws.demo \
            --auto-scaling-group-names "$ASG_NAME" \
            --query 'AutoScalingGroups[*].Instances[*].InstanceId' \
            --output text)"
          aws autoscaling set-instance-protection --instance-ids $INSTANCES \
            --profile aws.demo \
            --auto-scaling-group-name "$ASG_NAME" \
            --no-protected-from-scale-in
        done
      fi
CMD
  }

}

module "ec2_profile" {
  source = "terraform-aws-modules/ecs/aws//modules/ecs-instance-profile"

  name = var.cluster_name

  tags = {
    Environment = local.environment
  }
}

resource "aws_ecs_capacity_provider" "prov1" {
  name = "prov1"

  auto_scaling_group_provider {
    auto_scaling_group_arn = module.asg.this_autoscaling_group_arn
  }

}

#----- ECS  Services--------
module "hello_world" {
  source = "./service-hello-world"

  #cluster_id = module.ecs.this_ecs_cluster_id
  cluster_id = aws_ecs_cluster.this.id
  aws_lb_target_group = module.alb.target_group_arns[0]
  capacity_provider_name = aws_ecs_capacity_provider.prov1.name
}

#----- ECS  Resources--------

#For now we only use the AWS ECS optimized ami <https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-optimized_AMI.html>
data "aws_ami" "amazon_linux_ecs" {
  most_recent = true

  owners = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn-ami-*-amazon-ecs-optimized"]
  }

  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }
}

module "asg" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "~> 3.0"

  depends_on = [
    module.vpc
  ]

  name = local.ec2_resources_name

  key_name                = "demo-ssh-key"
  protect_from_scale_in = true
  target_group_arns          = module.alb.target_group_arns
  # Launch configuration
  lc_name = local.ec2_resources_name

  image_id             = data.aws_ami.amazon_linux_ecs.id
  instance_type        = "t2.micro"
  security_groups      = [module.security_group.this_security_group_id]
  iam_instance_profile = module.ec2_profile.this_iam_instance_profile_id
  user_data            = data.template_file.user_data.rendered

  # Auto scaling group
  asg_name                  = local.ec2_resources_name
  vpc_zone_identifier       = module.vpc.private_subnets
  #vpc_zone_identifier       = module.vpc.public_subnets
  health_check_type         = "EC2"
  min_size                  = 0
  max_size                  = 2
  desired_capacity          = 1 # we don't need them for the example
  wait_for_capacity_timeout = 0

  tags = [
    {
      key                 = "Environment"
      value               = local.environment
      propagate_at_launch = true
    },
    {
      key                 = "Cluster"
      value               = var.cluster_name
      propagate_at_launch = true
    }
  ]
}

data "template_file" "user_data" {
  template = file("${path.module}/templates/user-data.sh")

  vars = {
    cluster_name = var.cluster_name
  }
}