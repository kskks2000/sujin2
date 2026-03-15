# AWS deployment shape

This repository is structured for the following AWS runtime:

- `FastAPI` backend on ECS Fargate behind an ALB
- `PostgreSQL` on Amazon RDS
- `Redis` on Amazon ElastiCache
- `Flutter web` build deployed to S3 (CloudFront can be added next)

## Terraform assumptions

The Terraform in [`terraform/`](/Users/robert/kcastle/codex/sujin2/infra/aws/terraform) expects:

- an existing VPC
- existing public subnets for the ALB
- existing private subnets for ECS, RDS, and Redis
- a backend container image already pushed to ECR

## Next deployment steps

1. Build and push the FastAPI image to ECR.
2. Build Flutter web and upload `build/web` to the created S3 bucket.
3. Supply VPC and subnet IDs in `terraform.tfvars`.
4. Run Terraform apply from [`terraform/`](/Users/robert/kcastle/codex/sujin2/infra/aws/terraform).

## Production follow-ups

- add CloudFront for the Flutter web bucket
- add HTTPS certificates and Route 53 DNS
- move DB password to Secrets Manager
- add CI/CD for image build and S3 deploy
