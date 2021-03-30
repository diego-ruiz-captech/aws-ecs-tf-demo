# ECS EC2 ALB Demo

## Setup

This demo assumes you have aws credentials saved in an aws profile called `aws.demo`. In order to use terraform s3 state backend, you'll need to create the S3 bucket.

Example AWS CLI command (bucket name must be unique)
```
aws s3 mb s3://druiz-ec2-ecs-bucket --profile aws.demo
```

Next you can the terraform commands (reference s3 bucket in the options):

```
terraform init \
        -reconfigure \
        -backend-config="bucket=druiz-ec2-ecs-bucket" \
        -backend-config="key=tfstate" \
        -backend-config="region=us-east-1" \
        -backend-config="profile=aws.demo" \
        ./
terraform apply
```

### Output

Terraform outputs the ALB DNS name, a sample nginx hello container will be deployed and connected to this.

ECS Cluster
![output 1](./img/ecs-ec2-alb-demo-01.png)

Drill down to ECS Task to get public IP
![output 2](./img/ecs-ec2-alb-demo-02.png)

Sample Nginx hello using fargate public IP
![output 3](./img/ecs-ec2-alb-demo-03.png)

Additionally a ssh private key gets generated that can be used to connect to a bastion host

```
ssh -i ec2_private_key_pem ec2-user@BASTION_HOST_PUBLIC_IP
```

## Teardown

```
terraform destroy
```
