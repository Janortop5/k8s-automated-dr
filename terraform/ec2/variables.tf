variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "vpc_cidr_block" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnets" {
  type = map(any)
  default = {
    "k8s-project-public-1" = {
      name       = "public-1"
      az         = "us-east-1a"
      cidr_block = "10.0.1.0/24"
      key        = "k8s-project-public-1"
    },

    "k8s-project-public-2" = {
      name       = "public-2"
      az         = "us-east-1b"
      cidr_block = "10.0.2.0/24"
      key        = "k8s-project-public-2"
    }
  }
}

variable "private_subnets" {
  type = map(any)
  default = {
    "k8s-project-private-1" = {
      name       = "private-1"
      az         = "us-east-1a"
      cidr_block = "10.0.3.0/24"
    },

    "k8s-project-private-2" = {
      name       = "private-2"
      az         = "us-east-1b"
      cidr_block = "10.0.4.0/24"
    }
  }
}

variable "ec2_instance_sg" {
  type = map(any)
  default = {
    name        = "ec2_instance_sg"
    description = "security group for k8s-cluster ec2 instances"
  }
}

variable "ec2_instance_inbound_ports" {
  type    = list(number)
  default = [80, 443]
}

variable "ec2_instance_ssh_port" {
  type    = number
  default = 22
}

variable "alb_sg" {
  type = map(any)
  default = {
    name        = "alb_sg"
    description = "security group for k8s-cluster application load balancer"
  }
}

variable "ec2_instance_sg_ssh_cidr_block" {
  default = ["0.0.0.0/0"]
}

variable "alb_sg_cidr_block" {
  default = ["0.0.0.0/0"]
}

variable "alb_inbound_ports" {
  type    = list(number)
  default = [80, 443]
}

variable "ec2_instance_ami" {
  type    = string
  default = "ami-084568db4383264d4"
}

variable "ec2_instance_type" {
  type    = string
  default = "t3.small"
}

variable "ec2_instance_az1" {
  type = map(any)
  default = {
    k8s-cluster-server-1 = {
      az  = "us-east-1a"
      key = "k8s-cluster-master"
    }
    k8s-cluster-server-2 = {
      az  = "us-east-1a"
      key = "k8s-cluster-worker-1"
    }
  }
}

variable "ec2_instance_az2" {
  type = map(any)
  default = {
    k8s-cluster-server-3 = {
      az  = "us-east-1b"
      key = "k8s-cluster-worker-2"
    }
    jenkins-ci-server = {
      az  = "us-east-1b"
      key = "jenkins-ci-server"
    }
  }
}

variable "ec2_instance_key" {
  type    = string
  default = "k8s-cluster.pem"
}

variable "alb" {
  type = map(any)
  default = {
    name               = "k8s-lb"
    load_balancer_type = "application"
  }
}

variable "alb_target_group" {
  type = map(any)
  default = {
    name     = "k8s-target-group"
    port     = 80
    protocol = "HTTP"
  }
}

## uncomment this if going with HTTP only
#variable "alb_listener_1" {
#  type = map(any)
#  default = {
#    port        = "80"
#    protocol    = "HTTP"
#    action_type = "forward"
#  }
#}

variable "alb_listener_1" {
  type = map(any)
  default = {
    port        = "80"
    protocol    = "HTTP"
    action_type = "redirect"
    status_code = "HTTP_301"
  }
}

variable "alb_listener_2" {
  type = map(any)
  default = {
    port        = "443"
    protocol    = "HTTPS"
    action_type = "forward"
    ssl_policy = "ELBSecurityPolicy-2016-08"
  }
}

## uncomment this to provision DNS record
# variable "domain" {
#   type = map(any)
#   default = {
#     domain    = "eaaladejana.live"
#     subdomain = "terraform-test.eaaladejana.live"
#     type      = "A"
#   }
# }

## uncomment this to provision SSL cert
# variable "cert" {
#   type = map(any)
#   default = {
#     cert_1 = {
#       domain            = "eaaladejana.live"
#       validation_method = "DNS"
#     }

#     cert_2 = {
#       domain            = "terraform-test.eaaladejana.live"
#       validation_method = "DNS"
#     }
#   }
# }

variable "namedotcom_username" {
  default = ""
}

variable "namedotcom_token" {
  default = ""
}

variable "tags" {
  type = map(any)
  default = {
    vpc              = "k8s-vpc"
    internet_gateway = "k8s-igw"
    publicRT         = "k8s-publicRT"
    privateRT        = "k8s-privateRT"
    ec2_instance_sg  = "k8s-ec2-instance-sg"
    alb_sg           = "k8s-alb-sg"
    alb              = "k8s-alb"
    cert             = "k8s-ssl-cert"
  }
}
