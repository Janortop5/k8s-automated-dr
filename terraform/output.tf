output "instance_ids" {
  value = module.ec2.aws_instance[*].id
}

output "public_ips" {
  value = module.ec2.aws_instance[*].public_ip
}