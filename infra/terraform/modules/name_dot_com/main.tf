resource "namedotcom_record" "record" {
  domain_name = var.domain_name
  host        = var.jenkins_record_name               # e.g. "jenkins" → creates jenkins.example.com; ensure var.record_name is defined and matches the intended subdomain
  record_type = "A"
  answer      = var.record_ip
}