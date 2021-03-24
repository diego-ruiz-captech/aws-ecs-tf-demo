# Simple ECS + Fargate Demo

## Setup

This demo assumes you have aws credentials saved in an aws profile called `aws.demo`. In order to use terraform s3 state backend, you'll need to create the S3 bucket.

Example AWS CLI command (bucket name must be unique)
```
aws s3 mb s3://druiz-gs-fargate-ecs-bucket --profile aws.demo
```

Next you can the terraform commands (reference s3 bucket in the options):

```
terraform init \
        -reconfigure \
        -backend-config="bucket=druiz-gs-fargate-ecs-bucket" \
        -backend-config="key=tfstate" \
        -backend-config="region=us-east-1" \
        -backend-config="profile=aws.demo" \
        ./
terraform apply
```

### Output

There's is no explicit terraform output in this demo, however the deployed container can be viewed by using the public ip of the fargate container

Terraform output:
![output 1](./img/ecs-fargate-demo-01.png)

Sample Nginx hello ALB dns url
![output 2](./img/ecs-fargate-demo-02.png)

ECS cluster
![output 3](./img/ecs-fargate-demo-03.png)

## Teardown

```
terraform destroy
```

## Recommended Resources

- AWS Sys ops learning path - https://www.linkedin.com/learning/paths/prepare-for-aws-sysops-administrator-certification?u=2079044
- Learning Terraform course - https://www.linkedin.com/learning/learning-terraform-2?u=2079044
- Advanced Terraform course - https://www.linkedin.com/learning/advanced-terraform?u=2079044
- Devops Foundations course - https://www.linkedin.com/learning/devops-foundations-your-first-project?u=2079044
- Docker on AWS (ECS) course - https://www.linkedin.com/learning/docker-on-aws?u=2079044
- Terraform ECS Community Module - https://registry.terraform.io/modules/terraform-aws-modules/ecs
- Terraform ECS Community Module Example - https://github.com/terraform-aws-modules/terraform-aws-ecs/tree/master/examples/complete-ecs
- Terraform Security Group Community Module - https://registry.terraform.io/modules/terraform-aws-modules/security-group/aws/latest
- Terraform VPC Community Module - https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest
- Terraform ECS Cluster resource - https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster
- Terraform ECS Service resource - https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service
- Terraform ECS Task definition resource - https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition
- AWS Cloudformation ECS Task definition container definition documentation - https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-properties-ecs-taskdefinition-containerdefinitions.html