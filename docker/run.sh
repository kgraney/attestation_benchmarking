#!/bin/sh -x

# Assign an IP address to the loopback device.
ip addr add 127.0.0.1/32 dev lo
ip link set dev lo up

# Allow SSH access to the enclave.
/app/docker/socat VSOCK-LISTEN:5006,reuseaddr,fork TCP:localhost:22 &
/app/docker/socat VSOCK-LISTEN:5005,reuseaddr,fork TCP:localhost:8000 &

mkdir -p /root/.ssh
ssh-keygen -A
ssh-keygen -t rsa -N "" -f /root/.ssh/id_rsa
cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys
cat /app/docker/id_rsa.pub >> /root/.ssh/authorized_keys
cp /root/.ssh/id_rsa /app  # copy private key to HTTP root for fetching
/usr/sbin/sshd -D &

# Run the benchmarks and keep the container alive.
cd /app
cargo bench
python3 -m http.server 8000
