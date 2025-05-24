resource "aws_security_group" "ec2_instance_sg" {
  name        = var.ec2_instance_sg.name
  description = var.ec2_instance_sg.description
  vpc_id      = aws_vpc.vpc.id

  dynamic "ingress" {
    for_each = var.ec2_instance_k8s_inbound_ports
    content {
      from_port       = ingress.value.from_port
      to_port         = ingress.value.to_port
      protocol        = ingress.value.protocol
      description     = ingress.value.description
      cidr_blocks     = var.ec2_instance_sg_k8s_cidr_block
    }
  }
  
  dynamic "ingress" {
    for_each = var.ec2_instance_inbound_ports
    
    content {
      from_port       = ingress.value.from_port
      to_port         = ingress.value.to_port
      protocol        = ingress.value.protocol
      description     = ingress.value.description
      cidr_blocks     = var.ec2_instance_sg_cidr_block
    }
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = var.tags.ec2_instance_sg
  }
}


resource "aws_security_group" "alb_sg" {
  name        = var.alb_sg.name
  description = var.alb_sg.description
  vpc_id      = aws_vpc.vpc.id

  dynamic "ingress" {
    for_each = var.alb_inbound_ports
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = var.alb_sg_cidr_block
    }
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = var.tags.alb_sg
  }
}