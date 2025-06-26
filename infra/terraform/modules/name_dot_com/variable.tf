variable "domain_name" {
  description = "The apex domain you manage in Name.com (e.g. example.com)"
  type        = string
}

variable "jenkins_record_name" {
  description = "The DNS hostname you want to create under domain_name. For example, 'jenkins' will create 'jenkins.example.com'."
  type        = string
}

# The IP address to which the "jenkins_record_name" A-record should point
variable "record_ip" {
  description = "The IPv4 address for the A-record (e.g. the Jenkins EIP)"
  type        = string
}