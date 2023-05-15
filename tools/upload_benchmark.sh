#!/bin/bash
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


instance_type=$(curl http://169.254.169.254/latest/meta-data/instance-type)
instance_id=$(curl http://169.254.169.254/latest/meta-data/instance-id)

# This URL will return 200 when the benchmark finishes
health_url="http://localhost:8000/id_rsa"
while true; do
  status_code=$(curl -s -o /dev/null -w "%{http_code}" $health_url)

  if [[ $status_code -eq 200 ]]; then
    curl $health_url > $HOME/.ssh/id_rsa
    chmod 0600 $HOME/.ssh/id_rsa
    scp -r scp://root@localhost:2222//app/target/criterion /tmp
    scp -o StrictHostKeychecking=no -P 2222 -r root@127.0.0.1:/app/target/criterion /tmp
    aws s3 cp --recursive /tmp/criterion s3://nsm-benchmark-results/$instance_type/$instance_id/
    break
  else
    sleep 5
  fi
done
