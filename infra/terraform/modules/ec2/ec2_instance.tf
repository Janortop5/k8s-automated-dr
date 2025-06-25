resource "aws_instance" "ec2_instance-1-2" {
  for_each               = var.ec2_instance_az1
  ami                    = var.ec2_instance_ami
  instance_type          = var.ec2_instance_type
  key_name               = var.ec2_instance_key
  subnet_id              = aws_subnet.public_subnets[var.public_subnets.k8s-project-public-1.key].id
  vpc_security_group_ids = [aws_security_group.ec2_instance_sg.id]
  availability_zone      = each.value.az

  root_block_device {
    volume_size = 20
    delete_on_termination = true
  }

  tags = {
    Name = each.key
  }
  
}


resource "aws_eip" "az1" {
  for_each = aws_instance.ec2_instance-1-2
  
  tags = {
    Name = "eip-${each.key}"
  }
}

resource "aws_eip_association" "az1" {
  for_each      = aws_instance.ec2_instance-1-2
  instance_id   = each.value.id
  allocation_id = aws_eip.az1[each.key].id
}

resource "aws_instance" "ec2_instance-3-4" {
  for_each               = var.ec2_instance_az2
  ami                    = var.ec2_instance_ami
  instance_type          = var.ec2_instance_type
  key_name               = var.ec2_instance_key
  subnet_id              = aws_subnet.public_subnets[var.public_subnets.k8s-project-public-2.key].id
  vpc_security_group_ids = [aws_security_group.ec2_instance_sg.id]
  availability_zone      = each.value.az
 
  root_block_device {
    volume_size = 20
    delete_on_termination = true
  }
  
  tags = {
    Name = each.key
  }
}

resource "aws_eip" "az2" {
  for_each = aws_instance.ec2_instance-3-4
  
  tags = {
    Name = "eip-${each.key}"
  }
}

resource "aws_eip_association" "az2" {
  for_each      = aws_instance.ec2_instance-3-4
  instance_id   = each.value.id
  allocation_id = aws_eip.az2[each.key].id
}
