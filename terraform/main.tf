# 1. The Provider (Tells Terraform we are using AWS)
provider "aws" {
  region = "us-east-1"
}

# 2. ECR Repository (The "Garage" for your code)
# We store the Docker image here so AWS can download it later.
resource "aws_ecr_repository" "app_repo" {
  name = "vidumini-node-app" 
  force_delete = true
}

# 3. ECS Cluster (The "Neighborhood")
# This is a logical grouping where your services will live.
resource "aws_ecs_cluster" "app_cluster" {
  name = "vidumini-cluster"
}

# 4. Task Definition (The "Blueprint")
# This tells AWS: "Use 256 CPU, 512 RAM, and open port 8080."
resource "aws_ecs_task_definition" "app_task" {
  family                   = "vidumini-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([{
    name  = "vidumini-container"
    image = "${aws_ecr_repository.app_repo.repository_url}:latest" 
    portMappings = [{
      containerPort = 8080
      hostPort      = 8080
    }]
  }])
}

# 5. ECS Service (The "Manager")
# This ensures 1 copy of your website is always running.
resource "aws_ecs_service" "app_service" {
  name            = "vidumini-service"
  cluster         = aws_ecs_cluster.app_cluster.id
  task_definition = aws_ecs_task_definition.app_task.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    assign_public_ip = true
    security_groups  = [aws_security_group.app_sg.id]
  }
}

# 6. Security Group (The "Doorman")
# This allows traffic from the internet (0.0.0.0/0) to reach port 8080.
resource "aws_security_group" "app_sg" {
  name = "vidumini-sg"
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 7. IAM Role (The "ID Badge")
# This gives Fargate permission to download images from ECR.
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "vidumini-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# 8. Data Sources (Automatic Setup)
# These lines find your Default VPC automatically so you don't have to create one.
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# 9. Outputs (The "Result")
# This prints the ECR Link at the end. You need this link!
output "ecr_repository_url" {
  value = aws_ecr_repository.app_repo.repository_url
}