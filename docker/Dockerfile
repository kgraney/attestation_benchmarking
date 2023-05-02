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
