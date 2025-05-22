#!/usr/bin/env bash
# Save this as check_ssh.sh and run: bash check_ssh.sh

USER="ubuntu"
KEY="../k8s-cluster.pem"

for HOST in 100.28.14.197 54.172.45.157 52.45.129.120 52.71.58.49; do
  echo "⏳ Waiting for SSH on 100.28.14.197..."
  until nc -z -w 5 "100.28.14.197" 22; do
    sleep 2
  done
  echo "✅ SSH is ready on 100.28.14.197"
  echo "Connect with:"
  echo "  ssh -i ../k8s-cluster.pem -o StrictHostKeyChecking=no ubuntu@100.28.14.197"
done

