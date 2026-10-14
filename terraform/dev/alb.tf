resource "aws_lb" "api" {
  name               = "${local.ecs_name}-internal-alb"
  internal           = true
  load_balancer_type = "application"

  security_groups = [
    aws_security_group.alb.id
  ]

  subnets = [
    aws_subnet.private_app_a.id,
    aws_subnet.private_app_c.id
  ]

  enable_deletion_protection = false
  drop_invalid_header_fields = true

  tags = {
    Name    = "${local.ecs_name}-internal-alb"
    Service = "api"
  }
}

resource "aws_lb_target_group" "api" {
  name        = "${local.ecs_name}-api-tg"
  port        = var.api_container_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.main.id

  deregistration_delay = 30

  health_check {
    enabled             = true
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name    = "${local.ecs_name}-api-tg"
    Service = "api"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.api.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }

  tags = {
    Name = "${local.ecs_name}-http-listener"
  }
}