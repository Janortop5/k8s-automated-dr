If you're managing cloud infrastructure with Terraform and need to set up containerd as part of your deployment, you could:

Use Terraform to provision the infrastructure
Use Terraform to invoke Ansible for the containerd configuration (via the local-exec provisioner or dedicated Ansible provider)