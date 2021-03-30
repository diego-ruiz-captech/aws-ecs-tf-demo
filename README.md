# AWS ECS Terraform Demos

- [ECS, EC2, ALB Demo](ecs-ec2-alb/README.md)
- [Simple ECS Fargate Demo](ecs-fargate/README.md)
- [Codepipeline ECS Fargate Microservice Demo](ecs-fargate-ms/README.md)

## Todo

- ~~Ensure ecs containers can connect to aws resources (ie. s3, rds)~~
- Ensure ecs containers can communicate with each other
- Review and tune with security best practices
- ~~Link up with CI/CD resources for ECS deployments~~
- Submit demos to aws terraform ecs community module (they're still lacking fully fleshed out [examples](https://github.com/terraform-aws-modules/terraform-aws-ecs/tree/master/examples/complete-ecs))

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
- AWS ECR on ECS documentation - https://docs.aws.amazon.com/AmazonECR/latest/userguide/ECR_on_ECS.html
- AWS ECS Task secrets - https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_execution_IAM_role.html#task-execution-secrets
- Terraform IAM role - https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role
- IAM policy generator - https://awspolicygen.s3.amazonaws.com/policygen.html
- Terraform codepipeline resource - https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codepipeline
- Terraform codebuild resource - https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codebuild_project#environment
- AWS github connections - https://docs.aws.amazon.com/dtconsole/latest/userguide/connections-create-github.html
- Making AWS Codestar connection updates - https://docs.aws.amazon.com/dtconsole/latest/userguide/connections-update.html
- Using Codebuild in Codepipeline documentation - https://docs.aws.amazon.com/codepipeline/latest/userguide/action-reference-CodeBuild.html
- AWS sample codedeploy example - https://docs.aws.amazon.com/codebuild/latest/userguide/sample-codedeploy.html
- AWS ECS ECR Codedeploy tutorial - https://docs.aws.amazon.com/codepipeline/latest/userguide/tutorials-ecs-ecr-codedeploy.html#tutorials-ecs-ecr-codedeploy-deployment
- AWS Codebuild sample docker setup - https://docs.aws.amazon.com/codebuild/latest/userguide/sample-docker.html
- Terraform codestar connection resource - https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codestarconnections_connection
- AWS IAM Policy simulator - https://policysim.aws.amazon.com/home/index.jsp?
- Terraform Codedeploy group - https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codedeploy_deployment_group
- Good terraform example (ecs, codepipeline, etc.) - https://github.com/gnokoheat/ecs-with-codepipeline-example-by-terraform
- Codepipeline ECS Blue+Green deployment documentation - https://docs.aws.amazon.com/codepipeline/latest/userguide/action-reference-ECSbluegreen.html