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