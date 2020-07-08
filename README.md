# terraform-aws-ecs
Custom Terraform AWS ECS infrastructure 

Replace [YOU_BASE_DOMAIN] with your domain "example.com"
Replace [RANDOM-HASH] with some random hash for bucket
Replace [YOU_ACCOUNT_ID] with your account id like 000011112222

export AWS_PROFILE="[YOUR_PROFILE]"

cd 1-infrastructure

terraform init -backend-config="infrastructure-prod.config"
terraform plan -var-file="production.tfvars" 
terraform apply -var-file="production.tfvars" -auto-approve

cd ../2-platform

terraform init -backend-config="platform-prod.config"
terraform plan -var-file="production.tfvars"
terraform apply -var-file="production.tfvars" -auto-approve

cd ../3-application/infrastructure

sh deploy.sh build
sh deploy.sh dockerize
sh deploy.sh plan
sh deploy.sh deploy

// Resources for Demo

// VPC -> Subnets -> Route Tables -> Internet Gateway -> Elastic Ips -> Nat Gateway
// EC2 -> Security groups (springbootapp-SG) -> Target Groups -> Lad Balancer -> LB Rules -> Target Groups
// ECS -> Cluster -> Service > Tasks (from task definitions) ->

// elasticloadbalancing
https://docs.aws.amazon.com/elasticloadbalancing/latest/userguide/what-is-load-balancing.html

// autoscaling
https://docs.aws.amazon.com/autoscaling/ec2/userguide/what-is-amazon-ec2-auto-scaling.html

https://docs.aws.amazon.com/autoscaling/application/userguide/what-is-application-auto-scaling.html

https://springbootapp.[YOU_BASE_DOMAIN]/test

