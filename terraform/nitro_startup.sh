#!/bin/bash

# Install tools.
amazon-linux-extras install aws-nitro-enclaves-cli -y
yum install aws-nitro-enclaves-cli-devel -y
yum install amazon-ecr-credential-helper -y
yum install python3 -y

# Download custom build of recent socat with vsock support.
# (The version in Amazon Linux is too old)
su ec2-user -c 'aws s3 cp s3://kmg-ps-public/socat $HOME/socat'
su ec2-user -c 'chmod +x $HOME/socat'

# Setup Docker and the enclave config.
usermod -aG ne ec2-user
usermod -aG docker ec2-user
echo "---
memory_mib: 16192
cpu_count: 4" > /etc/nitro_enclaves/allocator.yaml

# Start Docker and Enclave services.
systemctl start nitro-enclaves-allocator.service && sudo systemctl enable nitro-enclaves-allocator.service
systemctl start docker && sudo systemctl enable docker

# Build the enclave from ECR and launch it.
su ec2-user -c 'eval $(aws ecr get-login --region us-east-1 --no-include-email) && docker pull 743396514183.dkr.ecr.us-east-1.amazonaws.com/nsm_benchmark:latest'
su ec2-user -c 'nitro-cli build-enclave --docker-uri 743396514183.dkr.ecr.us-east-1.amazonaws.com/nsm_benchmark:latest --output-file $HOME/nsm_benchmark.eif'
su ec2-user -c 'nitro-cli run-enclave --cpu-count 2 --enclave-cid 16 --memory 16192 --eif-path $HOME/nsm_benchmark.eif'

# Forward SSH to the vsock.
/home/ec2-user/socat TCP4-LISTEN:2222,reuseaddr,fork VSOCK-CONNECT:16:5006 &
/home/ec2-user/socat TCP4-LISTEN:8000,reuseaddr,fork VSOCK-CONNECT:16:5005 &

su ec2-user -c 'aws s3 cp s3://kmg-ps-public/upload_benchmark.sh $HOME/upload_benchmark.sh'
su ec2-user -c 'chmod +x $HOME/upload_benchmark.sh'
su ec2-user -c '$HOME/upload_benchmark.sh'
shutdown
