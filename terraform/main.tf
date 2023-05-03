terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 4.49"
    }
  }
  required_version = ">= 0.15"
}

provider "aws" {
  profile = "default"
  region = "us-east-1"
}

resource "aws_key_pair" "kmg" {
  key_name   = "kmg_keypair"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDfFO4peyUKMzoMW67opywcU/VnRfJpocMdneucDdNKWhhbxC9l8b2ihFUdEXxvzKE3iSeGn9PwUINCDYHbGX/KZIMX+KSg1wQFdtxk42kfzZhz/pxaSCdvhMXJiGnCD7VS1YMmF7ay2WaapqOBsjadx10BNXUDse1M9p9szDXC+3UHXKBnjNRjLB5ygWZECoYJ1+/GHaJf2NKxWokjI6G0wX5HOwbAkpH6iNxfZ3qXvzAxwJ+IzpGzqaU7+vqY5PARpHnfI+UEC/cyl9pnVjHs6skOJl7EF1ADXUrx2DPr3m1KOmqbQy4MENwuWGhxYL9kx42iejcS9iK0rk9tHBNzWNlPoqOPxrxibkG48MP83PJQmaVCyag5n7E1ZCJjNpMtdjTm7NXPcCaDxN98RXQzwDWpNAFECu0h0gGwtf018feMvUgidq4wOYGJp937Wyth7W0zks6gNmdba8KoD3+kxcjCdGfAqFTip+RUdAnlZLM5O5ErnxgXW4muA2016upWuP+SGy39e4oBa3TM+BqCW38OZNg+2AglweNNTZutWUA5iYBSsKQTER846yflZDo9J+weOdPylwAnTsiUcf3EzlxFxgZPtSZikhWQyFds9EVH8qx2zoP5reXVzilyGka9vkA0sUlWkRBqbH/NaItHFUh6pl31PFXXQ0dZhFyznQ== kmg@kmg.nyc.corp.google.com"
}

resource "aws_ecr_repository" "enclave_server_repository" {
  name = "nsm_benchmark"
  tags = {
    Name = "NsmBenchmarking"
  }
}

resource "aws_vpc" "enclave_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = "NsmBenchmarking"
  }
}

resource "aws_internet_gateway" "enclave_internet_gateway" {
  vpc_id = aws_vpc.enclave_vpc.id
  tags = {
    Name = "NsmBenchmarking"
  }
}

resource "aws_subnet" "enclave_subnet" {
  vpc_id = aws_vpc.enclave_vpc.id
  cidr_block = "10.0.1.0/24"
  tags = {
    Name = "NsmBenchmarking"
  }
}

resource "aws_route_table" "enclave_public_route" {
  vpc_id = aws_vpc.enclave_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.enclave_internet_gateway.id
  }
  tags = {
    Name = "NsmBenchmarking"
  }
}

resource "aws_route_table_association" "enclave_route_table_assn" {
  subnet_id      = aws_subnet.enclave_subnet.id
  route_table_id = aws_route_table.enclave_public_route.id
}

resource "aws_default_security_group" "enclave_server_sg" {
  vpc_id      = aws_vpc.enclave_vpc.id
  tags = {
    Name = "NsmBenchmark"
  }
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
  }
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
  }
  ingress {
    from_port       = 2222
    to_port         = 2222
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
  }
  egress {
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}


data "template_file" "enclave_server" {
  template = file("${path.module}/nitro_startup.sh")
  vars = {}
}

resource "aws_iam_role" "enclave_ec2_role" {
  name               = "nsm_benchmark_role"
  tags = {
    Name = "NsmBenchmarking"
  }
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": ["ec2.amazonaws.com"]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "enclave_ec2_role_policy" {
  name = "nsm_benchmarking_policy"
  tags = {
    Name = "NsmBenchmarking"
  }
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "ec2:DescribeInstances",
          "ecr:*",
          "s3:*",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_instance_profile" "enclave_server_profile" {
  name = "nsm_benchmarking_profile"
  role = aws_iam_role.enclave_ec2_role.name
  tags = {
    Name = "NsmBenchmarking"
  }
}

resource "aws_iam_policy_attachment" "attach" {
  name       = "enclave-attach"
  roles      = ["${aws_iam_role.enclave_ec2_role.name}"]
  policy_arn = "${aws_iam_policy.enclave_ec2_role_policy.arn}"
}

data "aws_ami" "enclave_server" {
  owners = ["amazon"]
  filter {
    name = "name"
    values = ["amzn2-ami-kernel-5.10-hvm-2.0.20220316.0-x86_64-gp2"]
  }
}

resource "aws_launch_template" "enclave_server" {
  name = "nsm-benchmark"
  image_id = data.aws_ami.enclave_server.id
  #instance_type = "c5.xlarge"
  user_data = base64encode(data.template_file.enclave_server.rendered)
  #subnet_id = aws_subnet.enclave_subnet.id
  key_name = aws_key_pair.kmg.id
  monitoring {
    enabled = true
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.enclave_server_profile.name
  }

  network_interfaces {
    associate_public_ip_address = true
  }

  enclave_options {
    enabled = true
  }

  lifecycle {
    create_before_destroy = true
  }
  tags = {
    Name = "NsmBenchmarking"
  }
}


locals {
  benchmarker_types = [
    #{ type = "c5.4xlarge", ami = "ami-0c02fb55956c7d316" },
    #{ type = "c5a.4xlarge", ami = "ami-0c02fb55956c7d316" },
    #{ type = "c5ad.4xlarge", ami = "ami-0c02fb55956c7d316" },
    #{ type = "c5d.4xlarge", ami = "ami-0c02fb55956c7d316" },
    #{ type = "c5n.4xlarge", ami = "ami-0c02fb55956c7d316" },
    #{ type = "c6a.4xlarge", ami = "ami-0c02fb55956c7d316" },
    #{ type = "c6i.4xlarge", ami = "ami-0c02fb55956c7d316" },
    #{ type = "c6id.4xlarge", ami = "ami-0c02fb55956c7d316" },
    #{ type = "c6in.4xlarge", ami = "ami-0c02fb55956c7d316" },
    #{ type = "d3.4xlarge", ami = "ami-0c02fb55956c7d316" },
    #{ type = "d3en.4xlarge", ami = "ami-0c02fb55956c7d316" },

    #{ type = "g4dn.4xlarge", ami = "ami-0c02fb55956c7d316" },
    #{ type = "g5.4xlarge", ami = "ami-0c02fb55956c7d316" },
    #{ type = "i4i.4xlarge", ami = "ami-0c02fb55956c7d316" },
    #{ type = "m5.4xlarge", ami = "ami-0c02fb55956c7d316" },
    #{ type = "m5a.4xlarge", ami = "ami-0c02fb55956c7d316" },
    #{ type = "m5ad.4xlarge", ami = "ami-0c02fb55956c7d316" },
    #{ type = "m5d.4xlarge", ami = "ami-0c02fb55956c7d316" },
    #{ type = "m5dn.4xlarge", ami = "ami-0c02fb55956c7d316" },
    #{ type = "m5n.4xlarge", ami = "ami-0c02fb55956c7d316" },
    #{ type = "m6a.4xlarge", ami = "ami-0c02fb55956c7d316" },
    #{ type = "m6i.4xlarge", ami = "ami-0c02fb55956c7d316" },
    #{ type = "m6id.4xlarge", ami = "ami-0c02fb55956c7d316" },
    #{ type = "m6idn.4xlarge", ami = "ami-0c02fb55956c7d316" },
    #{ type = "m6in.4xlarge", ami = "ami-0c02fb55956c7d316" },
    #{ type = "r5.4xlarge", ami = "ami-0c02fb55956c7d316" },

    #{ type = "r5a.4xlarge", ami = "ami-0c02fb55956c7d316" },
    #{ type = "r5ad.4xlarge", ami = "ami-0c02fb55956c7d316" },
    #{ type = "r5b.4xlarge", ami = "ami-0c02fb55956c7d316" },
    #{ type = "r5d.4xlarge", ami = "ami-0c02fb55956c7d316" },
    #{ type = "r5dn.4xlarge", ami = "ami-0c02fb55956c7d316" },
    #{ type = "r5n.4xlarge", ami = "ami-0c02fb55956c7d316" },
    #{ type = "r6a.4xlarge", ami = "ami-0c02fb55956c7d316" },
    #{ type = "r6i.4xlarge", ami = "ami-0c02fb55956c7d316" },
    #{ type = "r6id.4xlarge", ami = "ami-0c02fb55956c7d316" },
    #{ type = "r6idn.4xlarge", ami = "ami-0c02fb55956c7d316" },
    #{ type = "r6in.4xlarge", ami = "ami-0c02fb55956c7d316" },
    #{ type = "x2iedn.4xlarge", ami = "ami-0c02fb55956c7d316" },
    #{ type = "x2iezn.4xlarge", ami = "ami-0c02fb55956c7d316" },

    #{ type = "m5zn.2xlarge", ami = "ami-0c02fb55956c7d316" },
  ]

  benchmarkers = distinct(flatten([
    for replica in range(0, 3): [
      for bm_type in local.benchmarker_types : {
        replica = replica
        type = bm_type.type
        ami = bm_type.ami
      }
    ]
  ]))
}

resource "aws_instance" "benchmarkers" {
  for_each = {
    for bm in local.benchmarkers: "${bm.type}.${bm.replica}" => bm
  }
  ami = each.value.ami
  instance_type = each.value.type
  user_data = data.template_file.enclave_server.rendered
  enclave_options {
    enabled = true
  }
  root_block_device {
    volume_size = 32
    volume_type = "gp3"
  }
  associate_public_ip_address = true
  subnet_id = aws_subnet.enclave_subnet.id
  key_name = aws_key_pair.kmg.id
  iam_instance_profile = aws_iam_instance_profile.enclave_server_profile.name
  tags = {
    Name = "NsmBenchmark"
  }
}
