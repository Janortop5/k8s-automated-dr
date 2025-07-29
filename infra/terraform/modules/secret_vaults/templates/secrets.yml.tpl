---
# Velero AWS Credentials
aws_access_key_id: "${aws_access_key_id}"
aws_secret_access_key: "${aws_secret_access_key}"

# Velero Configuration
velero_bucket_name: "${velero_bucket_name}"
velero_region: "${velero_region}"

# Additional secrets can be added here
velero_backup_retention: "720h"
velero_volume_snapshot_locations: "aws"

# Remote vault token
remote_vault_token: "${remote_vault_token}"
remote_vault_address: "${remote_vault_address}"

# Remote Jenkins
jenkins_username: "${jenkins_username}"
jenkins_password: "${jenkins_password}"

# Git credentials
git_username: "${git_username}"
git_password: "${git_password}"