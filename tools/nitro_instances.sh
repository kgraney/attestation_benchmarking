#!/bin/bash
aws ec2 describe-instance-types \
  --filters "Name=hypervisor,Values=nitro" \
  --query "InstanceTypes[*].[InstanceType]" \
  --region=us-east-1 \
  --output=text | sort
