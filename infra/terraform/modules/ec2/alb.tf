###############################################################################
# modules/ec2/alb.tf   – always exactly one subnet per AZ
###############################################################################

# 1) Group all public subnets by AZ
locals {
  # e.g. { "us-west-2a" = ["subnet-aaa"], "us-west-2b" = ["subnet-bbb","subnet-ccc"] }
  alb_subnets_by_az = {
    for sn in aws_subnet.public_subnets :
    sn.availability_zone => sn.id...
  }

  # 2) Take the FIRST subnet in each list → map AZ → single subnet ID
  alb_subnet_by_az = {
    for az, ids in local.alb_subnets_by_az :
    az => ids[0]
  }

  # 3) ALB wants a plain list
  alb_subnet_ids = values(local.alb_subnet_by_az)
}

resource "aws_lb" "alb" {
  name               = var.alb.name
  load_balancer_type = var.alb.load_balancer_type
  internal           = false

  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = local.alb_subnet_ids         
  enable_deletion_protection = false

  tags = { Name = var.tags.alb }
}

resource "aws_lb_target_group" "alb_target_group" {
  name     = var.alb_target_group.name
  port     = var.alb_target_group.port
  protocol = var.alb_target_group.protocol
  vpc_id   = aws_vpc.vpc.id
}

# Attach masters & workers (skip Jenkins) in one loop
locals {
  tg_targets = {
    for k, v in local.all_instances :
    k => v if can(regex("k8s-cluster-", v.key))
  }
}

resource "aws_lb_target_group_attachment" "tg" {
  for_each         = local.tg_targets
  target_group_arn = aws_lb_target_group.alb_target_group.arn
  target_id        = aws_instance.nodes[each.key].id
  port             = var.alb_target_group.port
}
