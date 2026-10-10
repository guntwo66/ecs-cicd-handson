
# ALB：インターネットからのHTTPアクセスを受け付ける
resource "aws_lb" "app" {
  name               = "ecs-cicd-handson-alb"
  internal           = false
  load_balancer_type = "application"

  # network.tf で作成したALB用セキュリティグループ
  security_groups = [aws_security_group.alb.id]

  # ALBは異なる2つのAZのサブネットに配置する
  subnets = [
    aws_subnet.public_a.id,
    aws_subnet.public_b.id
  ]

  tags = {
    Project = "ecs-cicd-handson"
  }
}

# ターゲットグループ：アクセスを届けるECSタスクを登録する
resource "aws_lb_target_group" "app" {
  name        = "ecs-cicd-handson-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  # Webサーバーが正常に動作しているか確認する
  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
  }

  tags = {
    Project = "ecs-cicd-handson"
  }
}

# リスナー：HTTPの80番ポートでアクセスを受け付ける
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  # 受け取ったアクセスをターゲットグループへ転送する
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# ALBのDNS名をTerraformの実行結果に表示する
output "alb_dns_name" {
  description = "ALB DNS name for browser access"
  value       = aws_lb.app.dns_name
}
