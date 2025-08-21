#!/usr/bin/env bash
set -euo pipefail

# -------------------------------------------------------------------
# Configuration
# -------------------------------------------------------------------
PROFILES=(${AWS_PROFILES:-"dejanor"})
# If AWS_REGIONS is set, use those; otherwise discover all public regions
if [[ -n "${AWS_REGIONS:-}" ]]; then
  REGIONS=(${AWS_REGIONS})
else
  # Pull in all regions (public)
  mapfile -t REGIONS < <(
    aws ec2 describe-regions \
      --all-regions \
      --query 'Regions[].RegionName' \
      --output text \
    | tr '\t' '\n'
  )
fi

COMMAND=${1:-status}   # status | stop | start

export AWS_STS_REGIONAL_ENDPOINTS=regional

# -------------------------------------------------------------------
# Usage
# -------------------------------------------------------------------
show_usage() {
  cat <<EOF
Usage: $0 [command]

Commands:
  status  - Check status of all instances (default)
  stop    - Stop all running instances
  start   - Start all stopped instances

Environment vars:
  AWS_PROFILES   Space-separated list of AWS CLI profiles (default: 'dejanor')
  AWS_REGIONS    Space-separated list of regions to target (default: all public regions)
EOF
}

if [[ "${COMMAND}" =~ ^(-h|--help)$ ]]; then
  show_usage
  exit 0
fi

# -------------------------------------------------------------------
# Helpers
# -------------------------------------------------------------------
# Common wrapper that will run an AWS CLI command or skip on error
aws_or_skip() {
  "$@" || return 1
}

# -------------------------------------------------------------------
# EC2 Operations
# -------------------------------------------------------------------
check_instance_status() {
  local profile=$1 region=$2
  echo "=== [$profile] region: $region ==="
  
  # Get instance details with EIP information
  aws ec2 describe-instances \
    --profile "$profile" \
    --region  "$region" \
    --query 'Reservations[*].Instances[*].[InstanceId,State.Name,InstanceType,Tags[?Key==`Name`].Value|[0],PublicIpAddress,PrivateIpAddress]' \
    --output table || \
    echo "   (unable to describe instances)"
  
  echo
  check_elastic_ips "$profile" "$region"
}

check_elastic_ips() {
  local profile=$1 region=$2
  echo "Elastic IPs in $profile@$region:"
  
  local eip_data
  eip_data=$(aws_or_skip aws ec2 describe-addresses \
    --profile "$profile" \
    --region  "$region" \
    --query 'Addresses[*].[PublicIp,InstanceId,AssociationId,AllocationId,Tags[?Key==`Name`].Value|[0]]' \
    --output text) || {
    echo "   (unable to describe addresses)"
    return 0
  }

  if [[ -z "$eip_data" ]]; then
    echo "   No Elastic IPs found"
    return 0
  fi

  printf "%-15s %-19s %-21s %-10s %s\n" "Public IP" "Instance ID" "Association ID" "Status" "Name"
  printf "%-15s %-19s %-21s %-10s %s\n" "--------" "-----------" "--------------" "------" "----"
  
  while IFS=$'\t' read -r public_ip instance_id association_id allocation_id name; do
    local status
    if [[ -n "$instance_id" && "$instance_id" != "None" ]]; then
      status="attached"
    else
      status="unattached"
    fi
    
    printf "%-15s %-19s %-21s %-10s %s\n" \
      "${public_ip:-N/A}" \
      "${instance_id:-N/A}" \
      "${association_id:-N/A}" \
      "$status" \
      "${name:-<no-name>}"
  done <<<"$eip_data"
}

list_running_instances() {
  local profile=$1 region=$2
  local out
  out=$(aws_or_skip aws ec2 describe-instances \
    --profile "$profile" \
    --region  "$region" \
    --filters "Name=instance-state-name,Values=running" \
    --query 'Reservations[*].Instances[*].[InstanceId,Tags[?Key==`Name`].Value|[0],PublicIpAddress]' \
    --output text) || return 1

  if [[ -z "$out" ]]; then
    echo "No running instances in $profile@$region"
    return 1
  fi

  echo "Running instances in $profile@$region:"
  while read -r id name public_ip; do
    printf '  • %s (%s) - Public IP: %s\n' \
      "${name:-<no-name>}" \
      "$id" \
      "${public_ip:-none}"
  done <<<"$out"
}

list_stopped_instances() {
  local profile=$1 region=$2
  local out
  out=$(aws_or_skip aws ec2 describe-instances \
    --profile "$profile" \
    --region  "$region" \
    --filters "Name=instance-state-name,Values=stopped" \
    --query 'Reservations[*].Instances[*].[InstanceId,Tags[?Key==`Name`].Value|[0]]' \
    --output text) || return 1

  if [[ -z "$out" ]]; then
    echo "No stopped instances in $profile@$region"
    return 1
  fi

  echo "Stopped instances in $profile@$region:"
  while read -r id name; do
    printf '  • %s (%s)\n' "${name:-<no-name>}" "$id"
  done <<<"$out"
}

stop_instances() {
  local profile=$1 region=$2
  echo "Stopping all running instances in $profile@$region..."
  aws_or_skip aws ec2 stop-instances \
    --profile "$profile" \
    --region  "$region" \
    --filters "Name=instance-state-name,Values=running" \
    --query 'InstanceIds' \
    --output text \
  | xargs -r -n1 -I{} aws ec2 stop-instances --instance-ids {} --profile "$profile" --region "$region" \
    && echo "Done."
}

start_instances() {
  local profile=$1 region=$2
  echo "Starting all stopped instances in $profile@$region..."
  aws_or_skip aws ec2 start-instances \
    --profile "$profile" \
    --region  "$region" \
    --filters "Name=instance-state-name,Values=stopped" \
    --query 'InstanceIds' \
    --output text \
  | xargs -r -n1 -I{} aws ec2 start-instances --instance-ids {} --profile "$profile" --region "$region" \
    && echo "Done."
}

# -------------------------------------------------------------------
# Main Loop
# -------------------------------------------------------------------
for profile in "${PROFILES[@]}"; do
  for region in "${REGIONS[@]}"; do

    case "$COMMAND" in
      status)
        check_instance_status   "$profile" "$region"
        list_running_instances  "$profile" "$region" || true
        list_stopped_instances  "$profile" "$region" || true
        ;;
      stop)
        stop_instances "$profile" "$region"
        ;;
      start)
        start_instances "$profile" "$region"
        ;;
      *)
        echo "Unknown command: $COMMAND"
        show_usage
        exit 1
        ;;
    esac

    echo "----------------------------------------"
  done
done
