#!/bin/bash
aws ec2 describe-instance-types \
  --filters '[{"Name":"hypervisor","Values":["nitro"]},{"Name":"processor-info.supported-architecture","Values":["x86_64"]},{"Name":"vcpu-info.default-cores","Values":["8"]},{"Name":"bare-metal","Values":["false"]},{"Name":"burstable-performance-supported","Values":["false"]}]' \
  --region=us-east-1 \
  --query "InstanceTypes[*].[InstanceType]" \
  --output=text | sort
