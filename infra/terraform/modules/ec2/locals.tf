locals {
  master_entry = [  
    for name, obj in var.ec2_instance_az1 :  
    name  
    if obj.key == "k8s-cluster-master"  
  ][0]

  worker1_entry = [  
    for name, obj in var.ec2_instance_az1 :  
    name  
    if obj.key == "k8s-cluster-worker-1"  
  ][0]

  worker2_entry = [  
    for name, obj in var.ec2_instance_az2 :  
    name  
    if obj.key == "k8s-cluster-worker-2"  
  ][0]

  jenkins_entry = [  
    for name, obj in var.ec2_instance_az2 :  
    name  
    if obj.key == "jenkins-ci-server"  
  ][0]
}