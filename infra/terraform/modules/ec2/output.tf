###############################################################################
# modules/ec2/outputs.tf    – aligned with the refactored resources
###############################################################################

# ---------------------------------------------------------------------------
# 1.  All instances and their IDs (covers masters, workers, Jenkins, etc.)
# ---------------------------------------------------------------------------
output "instance_ids" {
  description = "EC2 instance IDs keyed by logical name"
  value       = { for k, v in aws_instance.nodes : k => v.id }
}

# ---------------------------------------------------------------------------
# 2.  All public IPs (1-to-1 with the instances above)
# ---------------------------------------------------------------------------
output "public_ips" {
  description = "Elastic IPs keyed by logical name"
  value       = { for k, e in aws_eip.nodes : k => e.public_ip }
}

# ---------------------------------------------------------------------------
# 3.  Convenience shortcuts – same roles you used before
# ---------------------------------------------------------------------------
output "master_public_ip" {
  description = "Public IP of the control-plane node"
  value       = aws_eip.nodes[local.master_entry].public_ip
}

output "worker_public_ips" {
  description = "Public IPs of worker nodes"
  value = {
    worker-1 = aws_eip.nodes[local.worker1_entry].public_ip
    worker-2 = aws_eip.nodes[local.worker2_entry].public_ip
  }
}

output "jenkins_public_ip" {
  description = "Public IP of the Jenkins server"
  value       = aws_eip.nodes[local.jenkins_entry].public_ip
}

output "debug_public_subnets" {
  value = {
    for k, sn in aws_subnet.public_subnets :
    k => sn.availability_zone
  }
}