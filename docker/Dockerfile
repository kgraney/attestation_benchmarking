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

FROM public.ecr.aws/amazonlinux/amazonlinux:2

RUN yum install python3 -y
RUN yum install cargo gnuplot -y
RUN yum install openssh-server openssh-clients initscripts -y
RUN yum install jq -y

WORKDIR /app
#COPY ./docker/socat /app/socat
#COPY ./docker/id_rsa.pub /app/authorized_keys
ADD . ./
RUN cargo clean
RUN cargo fetch
RUN cargo install cargo-criterion
#RUN cargo build --release
CMD ["/app/docker/run.sh"]
