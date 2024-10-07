resource "aws_launch_template" "instance_type" {
  name = "Instance_type"
  image_id = "ami-0862be96e41dcbf74"
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.sg_instance_type.id]
  user_data = base64encode(templatefile("file.sh",{}))
  lifecycle {
    create_before_destroy = true
  }
  }

resource "aws_security_group" "sg_instance_type" {
  # ... other configuration ...
name = "Inst-sg"
  ingress {
    from_port        = var.sever_port
    to_port          = var.sever_port
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
}
resource "aws_lb" "Lb_application" {
  name               = "lb-application-tf"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]
  subnets            = data.aws_subnets.subs.ids
}
resource "aws_security_group" "lb_sg" {
  # ... other configuration ...
name = "LB-sg"
  ingress {
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }
}
resource "aws_lb_listener" "Lb_listen" {
  load_balancer_arn = aws_lb.Lb_application.arn
  port = "80"
  protocol ="HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404 error response content"
      status_code  = "404"
    }
  }
}

resource "aws_lb_listener_rule" "lb_ral" {
  listener_arn = aws_lb_listener.Lb_listen.arn
  priority     = 100

  action {
    type = "forward"
    target_group_arn = aws_lb_target_group.tg_ex.arn
  }
   condition {
    path_pattern {
      values = ["*"]
    }
  }
}
resource "aws_lb_target_group" "tg_ex" {
  name     = "tf-lb-tg"
  port      = var.sever_port
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id
health_check {
  
     path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_autoscaling_group" "as-gr-project" {
  max_size           = 4
  min_size           = 1
  vpc_zone_identifier = data.aws_subnets.subs.ids
  target_group_arns = [aws_lb_target_group.tg_ex.arn]
  health_check_type = "ELB"

  launch_template {
    id      = aws_launch_template.instance_type.id
    version = aws_launch_template.instance_type.latest_version
  }

  tag {
    key                 = "name"
    value               = "tf-as"
    propagate_at_launch = true
  }

}
resource "aws_autoscaling_schedule" "Scale_out_mrng" {
  scheduled_action_name  = "schedule-scale-out"
  min_size               = 1
  max_size               = 3
  desired_capacity       = 3
  start_time             = "2024-07-19T06:00:00Z"
  recurrence = "00 06 * * *"
  autoscaling_group_name = aws_autoscaling_group.as-gr-project.name
  }
  resource "aws_autoscaling_schedule" "Scale_in_nyt" {
  scheduled_action_name  = "schedule-scale-in"
  min_size               = 2
  max_size               = 3
  desired_capacity       = 2
  start_time             = "2024-07-18T21:50:00Z"
  recurrence = "50 21 * * *"
  autoscaling_group_name = aws_autoscaling_group.as-gr-project.name
  }
