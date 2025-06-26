###############################################################################
# modules/ec2/locals.tf   – Region-agnostic & AZ-deduplicated
###############################################################################

############################################
# 1.  Region & Availability Zones  (deduped)
############################################
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  # DISTINCT() removes any duplicate AZ names the API might return
  azs = distinct(
    slice(
      data.aws_availability_zones.available.names,
      0,
      length(var.public_subnets)           # only as many as we need
    )
  )
}

############################################
# 2.  Subnet maps (same keys, new unique AZs)
############################################
locals {
  public_subnets = {
    for idx, key in sort(keys(var.public_subnets)) :
    key => merge(
      var.public_subnets[key],
      { az = local.azs[idx] }
    )
  }

  private_subnets = {
    for idx, key in sort(keys(var.private_subnets)) :
    key => merge(
      var.private_subnets[key],
      { az = local.azs[idx] }
    )
  }

  # Map AZ → public-subnet key  (used by EC2 & ALB)
  public_subnet_by_az = {
    for key, sn in local.public_subnets :
    sn.az => key
  }
}

############################################
# 3.  EC2 instance maps with Region-correct AZs
############################################
locals {
  ec2_instance_az1 = {
    for name, obj in var.ec2_instance_az1 :
    name => merge(obj, { az = local.azs[0] })
  }

  ec2_instance_az2 = {
    for name, obj in var.ec2_instance_az2 :
    name => merge(obj, { az = local.azs[1] })
  }

  all_instances = merge(local.ec2_instance_az1, local.ec2_instance_az2)
}

############################################
# 4.  Role look-ups
############################################
locals {
  host_by_role = {
    for name, obj in local.all_instances :
    obj.key => name
  }

  master_entry  = local.host_by_role["k8s-cluster-master"]
  worker1_entry = local.host_by_role["k8s-cluster-worker-1"]
  worker2_entry = local.host_by_role["k8s-cluster-worker-2"]
  jenkins_entry = local.host_by_role["jenkins-ci-server"]
}

############################################
# 5.  Region-aware Ubuntu 22.04 AMI
############################################
data "aws_ami" "ubuntu_22" {
  most_recent = true
  owners      = ["099720109477"]   # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

locals {
  ec2_ami = length(trimspace(var.ec2_instance_ami)) > 0 ? var.ec2_instance_ami : data.aws_ami.ubuntu_22.id
}

locals {
  # Absolute path  …/infra/k8s-cluster.pem
  key_path = abspath("${path.root}/../${var.ec2_instance_key}.pem")
}