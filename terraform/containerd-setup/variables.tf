variable "ssh_user" {
  description = "SSH username for the target host"
  type        = string
}

variable "host_ip" {
  description = "IP address of the target host"
  type        = string
}

variable "private_key_path" {
  description = "Path to the private SSH key"
  type        = string
}