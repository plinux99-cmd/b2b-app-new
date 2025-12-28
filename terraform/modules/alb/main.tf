resource "aws_lb" "this" {
  name               = "${var.name}-alb"
  load_balancer_type = "application"
  internal           = true

  subnets         = var.subnet_ids
  security_groups = var.security_groups

  tags = {
    Name = "${var.name}-alb"
  }
}

# Target group forwards traffic to Kubernetes workloads via IP targets.
resource "aws_lb_target_group" "app" {
  name        = "${var.name}-tg"
  port        = var.target_group_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 30
    timeout             = 5
    path                = var.health_check_path
    matcher             = "200-399"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}
