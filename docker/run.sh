#!/bin/sh -x
# Copyright 2023 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


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
#cargo criterion --message-format=json
/app/tools/run_benchmarks.sh
python3 -m http.server 8000
