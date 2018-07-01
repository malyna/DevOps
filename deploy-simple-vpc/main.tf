

provider "aws" {
  region = "${var.region}"
  access_key = "${var.access-key}}"
  secret_key = "${var.secret-key}}"
}

resource "aws_vpc" "simple-vpc" {
  cidr_block = "10.0.0.0/16"
  tags {
    Name = "${var.build-tag}"
  }
}

resource "aws_internet_gateway" "simple-gw" {
  vpc_id = "${aws_vpc.simple-vpc.id}"
  tags {
    Name = "${var.build-tag}"
  }
}

data "aws_availability_zones" "available-zones" {}

locals {
  used_azs_count = "${max(length(data.aws_availability_zones.available-zones.names), 3)}"
}

resource "aws_subnet" "simple-public" {
  count = "${local.used_azs_count}"
  cidr_block = "${cidrsubnet(aws_vpc.simple-vpc.cidr_block, 8,count.index * 10) }"
  vpc_id = "${aws_vpc.simple-vpc.id}"
  availability_zone = "${data.aws_availability_zones.available-zones.names[count.index]}"
  map_public_ip_on_launch = true
  tags {
    Name = "${var.build-tag}-public-${count.index}"
  }
}

resource "aws_subnet" "simple-private" {
  count = "${local.used_azs_count}"
  cidr_block = "${cidrsubnet(aws_vpc.simple-vpc.cidr_block, 8, count.index * 10 + 1) }"
  vpc_id = "${aws_vpc.simple-vpc.id}"
  availability_zone = "${data.aws_availability_zones.available-zones.names[count.index]}"
  tags {
    Name = "${var.build-tag}-private-${count.index}"
  }
}

resource "aws_subnet" "simple-private-db" {
  count = "${local.used_azs_count}"
  cidr_block = "${cidrsubnet(aws_vpc.simple-vpc.cidr_block, 8, count.index * 10 + 2) }"
  vpc_id = "${aws_vpc.simple-vpc.id}"
  availability_zone = "${data.aws_availability_zones.available-zones.names[count.index]}"
  tags {
    Name = "${var.build-tag}-private-db-${count.index}"
  }
}

resource "aws_nat_gateway" "simple-nat-gateway" {
  count = "${var.use-nat-gateway ? local.used_azs_count : 0}"
  allocation_id = ""
  subnet_id = "${aws_subnet.simple-public.*.id[count.index]}}"
  tags {
    Name = "${var.build-tag}-nat-gateway-${count.index}"
  }
}

resource "aws_instance" "simple-nat-box" {
  count = "${var.use-nat-gateway ? 0: local.used_azs_count}"
  ami = "das"
  instance_type = "t2.micro"
  subnet_id = "${aws_subnet.simple-public.*.id[count.index]}}"
}