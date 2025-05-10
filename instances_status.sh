#!/bin/bash

# Get configuration from environment variables or use defaults
# Use environment variables if set, otherwise use default values
PROFILES_ENV=${AWS_PROFILES:-"dejanor"}
PROFILES=(${PROFILES_ENV})
REGION=${AWS_REGION:-${1:-"us-east-1"}}
COMMAND=${2:-"status"} # Default command is status, can be: status, stop, start

# Make sure the AWS CLI is properly configured with the correct endpoint
export AWS_STS_REGIONAL_ENDPOINTS=regional

# Function to display usage
show_usage() {
    echo "Usage: $0 [region] [command]"
    echo ""
    echo "Commands:"
    echo "  status  - Check status of all instances (default)"
    echo "  stop    - Stop all running instances"
    echo "  start   - Start all stopped instances"
    echo ""
    echo "Environment variables:"
    echo "  AWS_PROFILES - Space-separated list of profiles (default: 'default bleh')"
    echo "  AWS_REGION   - AWS region (default: us-east-1)"
    echo ""
    echo "Examples:"
    echo "  $0                          # Check status in us-east-1"
    echo "  $0 eu-west-1                # Check status in eu-west-1"
    echo "  $0 us-east-1 stop           # Stop instances in us-east-1"
    echo "  AWS_PROFILES=\"prod dev\" $0   # Check profiles 'prod' and 'dev'"
}

# Show help if requested
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    show_usage
    exit 0
fi

# Function to check instance status
check_instance_status() {
    local profile=$1
    local region=$2
    
    echo "=== $profile ==="
    
    # Get all instances and their states
    aws ec2 describe-instances \
        --profile "$profile" \
        --region "$region" \
        --endpoint-url "https://ec2.$region.amazonaws.com" \
        --query 'Reservations[*].Instances[*].[InstanceId,State.Name,InstanceType,Tags[?Key==`Name`].Value|[0]]' \
        --output table
    
    echo "------------------"
    echo ""
}

# Function to list running instances and show stop commands
list_running_instances() {
    local profile=$1
    local region=$2
    
    RUNNING_INSTANCES=$(aws ec2 describe-instances \
        --profile "$profile" \
        --region "$region" \
        --endpoint-url "https://ec2.$region.amazonaws.com" \
        --filters "Name=instance-state-name,Values=running" \
        --query 'Reservations[*].Instances[*].[InstanceId,Tags[?Key==`Name`].Value|[0]]' \
        --output text)
    
    if [[ -n "$RUNNING_INSTANCES" ]]; then
        echo ""
        echo "Running instances in profile '$profile':"
        echo ""
        while read -r INSTANCE_ID NAME; do
            if [[ -n "$NAME" ]]; then
                echo "# Instance: $NAME (ID: $INSTANCE_ID)"
            else
                echo "# Instance ID: $INSTANCE_ID"
            fi
            
            INSTANCE_IP=$(aws ec2 describe-instances \
                --instance-ids "$INSTANCE_ID" \
                --profile "$profile" \
                --region "$region" \
                --endpoint-url "https://ec2.$region.amazonaws.com" \
                --query "Reservations[0].Instances[0].PublicIpAddress" \
                --output text)
            
            if [[ "$INSTANCE_IP" != "None" && -n "$INSTANCE_IP" ]]; then
                echo "# Public IP: $INSTANCE_IP"
            fi
            
            echo ""
        done <<< "$RUNNING_INSTANCES"
        
        return 0
    else
        echo "No running instances found in profile '$profile'"
        return 1
    fi
}

# Function to list stopped instances
list_stopped_instances() {
    local profile=$1
    local region=$2
    
    STOPPED_INSTANCES=$(aws ec2 describe-instances \
        --profile "$profile" \
        --region "$region" \
        --endpoint-url "https://ec2.$region.amazonaws.com" \
        --filters "Name=instance-state-name,Values=stopped" \
        --query 'Reservations[*].Instances[*].[InstanceId,Tags[?Key==`Name`].Value|[0]]' \
        --output text)
    
    if [[ -n "$STOPPED_INSTANCES" ]]; then
        echo ""
        echo "Stopped instances in profile '$profile':"
        echo ""
        while read -r INSTANCE_ID NAME; do
            if [[ -n "$NAME" ]]; then
                echo "# Instance: $NAME (ID: $INSTANCE_ID)"
            else
                echo "# Instance ID: $INSTANCE_ID"
            fi
            echo ""
        done <<< "$STOPPED_INSTANCES"
        
        return 0
    else
        echo "No stopped instances found in profile '$profile'"
        return 1
    fi
}

# Function to stop running instances
stop_instances() {
    local profile=$1
    local region=$2
    
    RUNNING_INSTANCES=$(aws ec2 describe-instances \
        --profile "$profile" \
        --region "$region" \
        --endpoint-url "https://ec2.$region.amazonaws.com" \
        --filters "Name=instance-state-name,Values=running" \
        --query 'Reservations[*].Instances[*].[InstanceId,Tags[?Key==`Name`].Value|[0]]' \
        --output text)
    
    if [[ -n "$RUNNING_INSTANCES" ]]; then
        echo "Stopping instances in profile '$profile':"
        
        while read -r INSTANCE_ID NAME; do
            echo -n "Stopping instance"
            if [[ -n "$NAME" ]]; then
                echo -n " $NAME"
            fi
            echo -n " ($INSTANCE_ID)... "
            
            aws ec2 stop-instances \
                --profile "$profile" \
                --region "$region" \
                --endpoint-url "https://ec2.$region.amazonaws.com" \
                --instance-ids "$INSTANCE_ID" \
                --output json > /dev/null
            
            if [ $? -eq 0 ]; then
                echo "Done"
            else
                echo "Failed"
            fi
        done <<< "$RUNNING_INSTANCES"
        
        echo "Finished stopping instances in profile '$profile'"
    else
        echo "No running instances found in profile '$profile'"
    fi
}

# Function to start stopped instances
start_instances() {
    local profile=$1
    local region=$2
    
    STOPPED_INSTANCES=$(aws ec2 describe-instances \
        --profile "$profile" \
        --region "$region" \
        --endpoint-url "https://ec2.$region.amazonaws.com" \
        --filters "Name=instance-state-name,Values=stopped" \
        --query 'Reservations[*].Instances[*].[InstanceId,Tags[?Key==`Name`].Value|[0]]' \
        --output text)
    
    if [[ -n "$STOPPED_INSTANCES" ]]; then
        echo "Starting instances in profile '$profile':"
        
        while read -r INSTANCE_ID NAME; do
            echo -n "Starting instance"
            if [[ -n "$NAME" ]]; then
                echo -n " $NAME"
            fi
            echo -n " ($INSTANCE_ID)... "
            
            aws ec2 start-instances \
                --profile "$profile" \
                --region "$region" \
                --endpoint-url "https://ec2.$region.amazonaws.com" \
                --instance-ids "$INSTANCE_ID" \
                --output json > /dev/null
            
            if [ $? -eq 0 ]; then
                echo "Done"
            else
                echo "Failed"
            fi
        done <<< "$STOPPED_INSTANCES"
        
        echo "Finished starting instances in profile '$profile'"
    else
        echo "No stopped instances found in profile '$profile'"
    fi
}

# Main loop
for PROFILE in "${PROFILES[@]}"; do
    # Skip empty profiles
    if [[ -z "$PROFILE" ]]; then
        continue
    fi
    
    case "$COMMAND" in
        "status")
            check_instance_status "$PROFILE" "$REGION"
            list_running_instances "$PROFILE" "$REGION"
            list_stopped_instances "$PROFILE" "$REGION"
            ;;
        "stop")
            stop_instances "$PROFILE" "$REGION"
            ;;
        "start")
            start_instances "$PROFILE" "$REGION"
            ;;
        *)
            echo "Unknown command: $COMMAND"
            show_usage
            exit 1
            ;;
    esac
    
    echo "------------------"
    echo ""
done

# Show available commands
echo "Available commands:"
echo "  $0                  # Check status"
echo "  $0 us-east-1 stop   # Stop all running instances"
echo "  $0 us-east-1 start  # Start all stopped instances"
echo ""