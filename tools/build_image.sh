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

ecr_repo=743396514183.dkr.ecr.us-east-1.amazonaws.com
ecr_image=$ecr_repo/nsm_benchmark:latest
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ecr_repo

aws s3 cp ./tools/upload_benchmark.sh s3://kmg-ps-public/
docker build -f ./docker/Dockerfile ./ -t benchmark
docker tag benchmark:latest $ecr_image
docker push $ecr_image
