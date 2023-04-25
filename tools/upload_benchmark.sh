#!/bin/bash

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
