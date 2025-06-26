
###############################################################################
# all EC2 nodes (masters, workers, Jenkins) – one block instead of two
###############################################################################
###############################################################################
# EC2 nodes  (notice: availability_zone removed)
###############################################################################
resource "aws_instance" "nodes" {
  for_each          = local.all_instances

  ami               = local.ec2_ami
  instance_type     = var.ec2_instance_type
  key_name          = aws_key_pair.cluster.key_name          # uses the created pair
  subnet_id         = aws_subnet.public_subnets[
                       local.public_subnet_by_az[each.value.az]
                     ].id
  vpc_security_group_ids = [aws_security_group.ec2_instance_sg.id]

  root_block_device {
    volume_size           = 20
    delete_on_termination = true
  }

  tags = merge(var.tags, { Name = each.key })
}

###############################################################################
# 1 × EIP per instance
###############################################################################
resource "aws_eip" "nodes" {
  for_each = aws_instance.nodes
  tags = {
    Name = "eip-${each.key}"
  }
}

resource "aws_eip_association" "nodes" {
  for_each      = aws_instance.nodes
  instance_id   = each.value.id
  allocation_id = aws_eip.nodes[each.key].id
}
