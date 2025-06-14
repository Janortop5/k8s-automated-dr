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
# Check region access: skip if no AZs are visible

# Common wrapper that will run an AWS CLI command or skip on error
aws_or_skip() {
  "$@" 2>/dev/null || return 1
}

# -------------------------------------------------------------------
# EC2 Operations
# -------------------------------------------------------------------
check_instance_status() {
  local profile=$1 region=$2
  echo "=== [$profile] region: $region ==="
  aws_or_skip aws ec2 describe-instances \
    --profile "$profile" \
    --region  "$region" \
    --query 'Reservations[*].Instances[*].[InstanceId,State.Name,InstanceType,Tags[?Key==`Name`].Value|[0]]' \
    --output table || \
    echo "   (unable to describe instances)"
}

list_running_instances() {
  local profile=$1 region=$2
  local out
  out=$(aws_or_skip aws ec2 describe-instances \
    --profile "$profile" \
    --region  "$region" \
    --filters "Name=instance-state-name,Values=running" \
    --query 'Reservations[*].Instances[*].[InstanceId,Tags[?Key==`Name`].Value|[0]]' \
    --output text) || return 1

  if [[ -z "$out" ]]; then
    echo "No running instances in $profile@$region"
    return 1
  fi

  echo "Running instances in $profile@$region:"
  while read -r id name; do
    printf '  • %s (%s)\n' "${name:-<no-name>}" "$id"
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
