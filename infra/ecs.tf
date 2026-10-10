
# ECSクラスター：コンテナを管理する場所
resource "aws_ecs_cluster" "main" {
  name = "ecs-cicd-handson"

  tags = {
    Project = "ecs-cicd-handson"
  }
}

# ECSタスクがAWSのサービスを利用するためのIAMロール
resource "aws_iam_role" "ecs_task_execution" {
  name = "ecs-cicd-handson-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

# ECRからイメージを取得し、CloudWatch Logsにログを書き込む権限
resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# コンテナのログを保存する場所
resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/ecs-cicd-handson"
  retention_in_days = 7

  tags = {
    Project = "ecs-cicd-handson"
  }
}

# コンテナの起動設定（タスク定義）
resource "aws_ecs_task_definition" "app" {
  family                   = "ecs-cicd-handson"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name      = "app"
      image     = "${aws_ecr_repository.app.repository_url}:manual-test"
      essential = true

      portMappings = [{
        containerPort = 80
        protocol      = "tcp"
      }]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.app.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "app"
        }
      }
    }
  ])

  depends_on = [
    aws_iam_role_policy_attachment.ecs_task_execution
  ]

  tags = {
    Project = "ecs-cicd-handson"
  }
}

# ECSサービス：Fargate上でコンテナを継続稼働させる
resource "aws_ecs_service" "app" {
  name            = "ecs-cicd-handson-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  # Fargateタスクを配置するネットワーク
  network_configuration {
    subnets = [
      aws_subnet.public_a.id,
      aws_subnet.public_b.id
    ]

    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = true
  }

  # ALBからのアクセスをコンテナに届ける
  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "app"
    container_port   = 80
  }

  # ALBのリスナーを作成してからサービスを作る
  depends_on = [
    aws_lb_listener.http
  ]

  # GitHub Actionsによるデプロイ後、Terraformが
  # タスク定義を元に戻さないようにする
  lifecycle {
    ignore_changes = [task_definition]
  }

  tags = {
    Project = "ecs-cicd-handson"
  }
}
