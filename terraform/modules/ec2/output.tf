output "instance_ids_1_2" {
  value = { for k, v in aws_instance.ec2_instance-1-2 : k => v.id }
}

output "public_ips_1_2" {
  value = { for k, v in aws_instance.ec2_instance-1-2 : k => v.public_ip }
}

output "instance_ids_3_4" {
  value = { for k, v in aws_instance.ec2_instance-3-4 : k => v.id }
}

output "public_ips_3_4" {
  value = { for k, v in aws_instance.ec2_instance-3-4 : k => v.public_ip }
}

output "master_public_ip" {
  description = "Master node"
  value       = try(aws_instance.ec2_instance-1-2[local.master_entry].public_ip, "")
}

output "worker_public_ips" {
  description = "Worker nodes"
  value = {
    worker-1 = try(aws_instance.ec2_instance-1-2[local.worker1_entry].public_ip, "")
    worker-2 = try(aws_instance.ec2_instance-3-4[local.worker2_entry].public_ip, "")
  }
}

output "jenkins_public_ip" {
  description = "Jenkins server"
  value       = try(aws_instance.ec2_instance-3-4[local.jenkins_entry].public_ip, "")
}