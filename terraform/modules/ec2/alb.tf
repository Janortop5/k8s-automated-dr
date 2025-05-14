resource "aws_lb" "alb" {
  name               = var.alb.name
  internal           = false
  load_balancer_type = var.alb.load_balancer_type
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_subnets[var.public_subnets.k8s-project-public-1.key].id, aws_subnet.public_subnets[var.public_subnets.k8s-project-public-2.key].id]

  enable_deletion_protection = false

  depends_on = [
    aws_security_group.alb_sg
  ]

  tags = {
    Name = var.tags.alb
  }
}

resource "aws_lb_target_group" "alb_target_group" {
  name     = var.alb_target_group.name
  port     = var.alb_target_group.port
  protocol = var.alb_target_group.protocol
  vpc_id   = aws_vpc.vpc.id
}

resource "aws_lb_target_group_attachment" "alb_tg_attachment_1" {
  for_each         = var.ec2_instance_az1
  target_group_arn = aws_lb_target_group.alb_target_group.arn
  target_id        = aws_instance.ec2_instance-1-2[each.key].id
  port             = var.alb_target_group.port
}

resource "aws_lb_target_group_attachment" "alb_tg-attachment_2" {
  for_each         = var.ec2_instance_az2
  target_group_arn = aws_lb_target_group.alb_target_group.arn
  target_id        = aws_instance.ec2_instance-3-4[each.key].id
  port             = var.alb_target_group.port
}

