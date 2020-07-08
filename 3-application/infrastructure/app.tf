provider "aws" {
  region = var.region
}

terraform {
  backend "s3" {
  }
}


// Read existing remote state variables
data "terraform_remote_state" "platform" {
  backend = "s3"

  config = {
    key    = var.remote_state_key
    bucket = var.remote_state_bucket
    region = var.region
  }
}

// Terraform way to populate template file with terraform variables
data "template_file" "ecs_task_definition_template" {
  template = file("task_definition.json")

  vars = {
    task_definition_name  = var.ecs_service_name
    ecs_service_name      = var.ecs_service_name
    docker_image_url      = var.docker_image_url
    memory                = var.memory
    docker_container_port = var.docker_container_port
    spring_profile        = var.spring_profile
    region                = var.region
  }
}

//
resource "aws_ecs_task_definition" "springbootapp-task-definition" {
  // Template file with rendered variables
  container_definitions    = data.template_file.ecs_task_definition_template.rendered
  // Just ecs service name
  family                   = var.ecs_service_name
  // ???
  cpu                      = 512
  //
  memory                   = var.memory
  // Set FarGate as a target way to manage ECS
  requires_compatibilities = ["FARGATE"]
  // ???
  network_mode             = "awsvpc"
  // Let Fargete Task to use AWS resourses
  execution_role_arn       = aws_iam_role.fargate_iam_role.arn
  task_role_arn            = aws_iam_role.fargate_iam_role.arn
}

resource "aws_iam_role" "fargate_iam_role" {
  name               = "${var.ecs_service_name}-IAM-Role"
  assume_role_policy = <<EOF
{
"Version": "2012-10-17",
"Statement": [
  {
    "Effect": "Allow",
    "Principal": {
      "Service": ["ecs.amazonaws.com", "ecs-tasks.amazonaws.com"]
    },
    "Action": "sts:AssumeRole"
  }
  ]
}
EOF

}

resource "aws_iam_role_policy" "fargate_iam_role_policy" {
  name = "${var.ecs_service_name}-IAM-Role-Policy"
  role = aws_iam_role.fargate_iam_role.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecs:*",
        "ecr:*",
        "logs:*",
        "cloudwatch:*",
        "elasticloadbalancing:*"
      ],
      "Resource": "*"
    }
  ]
}
EOF

}

// control traffic between containert in ECS to the external internet
resource "aws_security_group" "app_security_group" {
  name        = "${var.ecs_service_name}-SG"
  description = "Security group for springbootapp to communicate in and out"
  vpc_id      = data.terraform_remote_state.platform.outputs.vpc_id

  ingress {
    from_port = 8080
    protocol  = "TCP"
    to_port   = 8080
    cidr_blocks = [data.terraform_remote_state.platform.outputs.vpc_cidr_block]
  }

  egress {
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.ecs_service_name}-SG"
  }
}

// ???
resource "aws_alb_target_group" "ecs_app_target_group" {
  name        = "${var.ecs_service_name}-TG"
  port        = var.docker_container_port
  protocol    = "HTTP"
  vpc_id      = data.terraform_remote_state.platform.outputs.vpc_id
  target_type = "ip"

  // ECS could undestand that my apps are healthy
  health_check {
    // check any helthcheck endpoin
    path                = "/actuator/health"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 60
    timeout             = 30
    // number of retries
    unhealthy_threshold = "3"
    healthy_threshold   = "3"
  }

  tags = {
    Name = "${var.ecs_service_name}-TG"
  }
}

resource "aws_ecs_service" "ecs_service" {
  name            = var.ecs_service_name
  task_definition = var.ecs_service_name
  desired_count   = var.desired_task_number

  // Consume hardvare and network resourses
  cluster         = data.terraform_remote_state.platform.outputs.ecs_cluster_name
  launch_type     = "FARGATE"

  network_configuration {
    // Public subnets to enable public ip a
    subnets          = data.terraform_remote_state.platform.outputs.ecs_public_subnets
    security_groups  = [aws_security_group.app_security_group.id]
    // Public ip address
    assign_public_ip = true
  }

  load_balancer {
    container_name   = var.ecs_service_name
    // docker container port
    container_port   = var.docker_container_port
    target_group_arn = aws_alb_target_group.ecs_app_target_group.arn
  }

}

// Taget group -> LB relation with some listener configuration
resource "aws_alb_listener_rule" "ecs_alb_listener_rule" {
  listener_arn = data.terraform_remote_state.platform.outputs.ecs_alb_listener_arn

  action {
    // ???
    type             = "forward"
    target_group_arn = aws_alb_target_group.ecs_app_target_group.arn
  }

  condition {
    // Create sub domain in LB
    field  = "host-header"
    values = ["${lower(var.ecs_service_name)}.${data.terraform_remote_state.platform.outputs.ecs_domain_name}"]
  }
}

resource "aws_cloudwatch_log_group" "springbootapp_log_group" {
  name = "${var.ecs_service_name}-LogGroup"
}

