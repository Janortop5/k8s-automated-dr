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
  value = try(
    aws_instance.ec2_instance-3-4[var.ec2_instance_az2.jenkins-ci-server.key].public_ip,
    ""
  )
}

output "worker_public_ips" {
  description = "Public IPs of all worker nodes (filters out any that aren’t actually created)"
  value = {
    worker-1 = try(
      aws_instance.ec2_instance-1-2[var.ec2_instance_az1.k8s-cluster-server-2.key].public_ip,
      ""
    ),
    worker-2 = try(
      aws_instance.ec2_instance-3-4[var.ec2_instance_az2.k8s-cluster-server-3.key].public_ip,
      ""
    ),
  }
}

output "jenkins_public_ip" {
  description = "Public IP of the Jenkins server"
  value = try(
    aws_instance.ec2_instance-3-4[var.ec2_instance_az2.jenkins-ci-server.key].public_ip,
    ""
  )
}