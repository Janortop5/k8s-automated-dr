###########################
# 1. Generate a new RSA key
###########################
resource "tls_private_key" "cluster" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

###########################
# 2. Upload the public key to AWS
###########################
resource "aws_key_pair" "cluster" {
  key_name   = var.ec2_instance_key               # "k8s-cluster"
  public_key = tls_private_key.cluster.public_key_openssh
}

###########################
# 3. Write the private key locally
###########################
resource "local_file" "private_key" {
  content         = tls_private_key.cluster.private_key_pem
  filename        = local.key_path           # ← one level above terraform/
  file_permission = "0600"
}
