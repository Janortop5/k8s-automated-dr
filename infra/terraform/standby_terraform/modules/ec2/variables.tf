########################
# VPC & SUBNET SHAPES
########################
variable "vpc_cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

# ── PUBLIC subnets ─────────────────────────────────────────
# Keys stay identical ("k8s-project-public-1", …) but no AZ field:
variable "public_subnets" {
  description = "Public subnet definitions (module fills in AZs automatically)"
  type = map(object({
    name       = string
    cidr_block = string
    key        = string
  }))
  default = {
    "k8s-project-public-1" = {
      name       = "public-1"
      cidr_block = "10.0.1.0/24"
      key        = "k8s-project-public-1"
    }
    "k8s-project-public-2" = {
      name       = "public-2"
      cidr_block = "10.0.2.0/24"
      key        = "k8s-project-public-2"
    }
  }
}

# ── PRIVATE subnets ────────────────────────────────────────
variable "private_subnets" {
  description = "Private subnet definitions (AZs supplied inside module)"
  type = map(object({
    name       = string
    cidr_block = string
  }))
  default = {
    "k8s-project-private-1" = {
      name       = "private-1"
      cidr_block = "10.0.3.0/24"
    }
    "k8s-project-private-2" = {
      name       = "private-2"
      cidr_block = "10.0.4.0/24"
    }
  }
}

########################
# SECURITY-GROUP SHAPES
########################
variable "ec2_instance_sg" {
  description = "Metadata + allowed CIDRs for the node security group"
  type = object({
    name        = string
    description = string
    cidr_block  = list(string)      
  })
  default = {
    name        = "ec2_instance_sg"
    description = "security group for k8s-cluster EC2 instances"
    cidr_block  = ["0.0.0.0/0"]
  }
}

variable "ec2_instance_k8s_inbound_ports" {
  description = "Ports that masters & workers need for Kubernetes traffic"
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    description = string
  }))
  default = [
    { from_port = 6443,  to_port = 6443,  protocol = "tcp", description = "Kubernetes API" },
    { from_port = 3000,  to_port = 10000, protocol = "tcp", description = "Application ports" },
    { from_port = 30000, to_port = 32767, protocol = "tcp", description = "NodePort services" },
    { from_port = 179,   to_port = 179,   protocol = "tcp", description = "Calico BGP" },
    { from_port = 10249, to_port = 10259, protocol = "tcp", description = "Kubelet API" },
  ]
}

variable "ec2_instance_inbound_ports" {
  description = "Basic admin / web ingress to the nodes"
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    description = string
  }))
  default = [
    { from_port = 22,  to_port = 22,  protocol = "tcp", description = "SSH"   },
    { from_port = 80,  to_port = 80,  protocol = "tcp", description = "HTTP"  },
    { from_port = 443, to_port = 443, protocol = "tcp", description = "HTTPS" },
  ]
}

########################
# ALB   (unchanged)
########################
variable "alb_sg" {
  description = "Metadata + allowed CIDRs for the ALB security group"
  type = object({
    name        = string
    description = string
    cidr_block  = list(string)
  })
  default = {
    name        = "alb_sg"
    description = "security group for k8s-cluster ALB"
    cidr_block  = ["0.0.0.0/0"]
  }
}

variable "alb_inbound_ports" {
  type    = list(number)
  default = [80, 443]
}
  
variable "alb" {
  type = map(string)
  default = {
    name               = "standby-k8s-lb"
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

variable "alb_listener_1" {
  type = map(any)
  default = {
    port        = "80"
    protocol    = "HTTP"
    action_type = "forward"
  }
}

variable "alb_listener_2" {
  type = map(any)
  default = {
    port        = "443"
    protocol    = "HTTPS"
    action_type = "forward"
    ssl_policy  = "ELBSecurityPolicy-2016-08"
  }
}

########################
# EC2 INSTANCE MAPS
########################
# 1st AZ workload map – keep variable name; module fills AZ later
variable "ec2_instance_az1" {
  type = map(object({
    key = string
  }))
  default = {
    k8s-cluster-server-1 = { key = "k8s-cluster-master"  }
    k8s-cluster-server-2 = { key = "k8s-cluster-worker-1"}
  }
}

# 2nd AZ workload map
variable "ec2_instance_az2" {
  type = map(object({
    key = string
  }))
  default = {
    k8s-cluster-server-3 = { key = "k8s-cluster-worker-2"}
  }
}

variable "ec2_instance_type" {
  description = "Instance size for all nodes"
  type        = string
  default     = "t3.small"
}

# Allow an override; module will supply the latest Ubuntu AMI if null
variable "ec2_instance_ami" {
  description = "Custom AMI ID (leave blank to auto-select latest Ubuntu 22.04)"
  type        = string
  default     = ""
}

variable "ec2_instance_key" {
  description = "Key-pair name injected into EC2 instances"
  type        = string
  default     = "standby-k8s-cluster"
}

########################
# TAGS  (unchanged)
########################
variable "tags" {
  type = map(string)
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

