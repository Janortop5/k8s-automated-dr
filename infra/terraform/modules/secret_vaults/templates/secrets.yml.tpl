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