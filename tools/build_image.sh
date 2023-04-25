#!/bin/bash
ecr_repo=743396514183.dkr.ecr.us-east-1.amazonaws.com
ecr_image=$ecr_repo/nsm_benchmark:latest
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ecr_repo

aws s3 cp ./tools/upload_benchmark.sh s3://kmg-ps-public/
docker build -f ./docker/Dockerfile ./ -t benchmark
docker tag benchmark:latest $ecr_image
docker push $ecr_image
