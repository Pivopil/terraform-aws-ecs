# remote state
remote_state_key    = "PROD/infrastructure.tfstate"
remote_state_bucket = "ecs-fargate-terraform-remote-state-[RANDOM-HASH]"

ecs_domain_name      = "[YOU_BASE_DOMAIN]"
ecs_cluster_name     = "Production-ECS-Cluster"
internet_cidr_blocks = "0.0.0.0/0"
