provider "aws" {
  region = "${var.region}"
  access_key = "${var.access-key}"
  secret_key = "${var.secret-key}"
}

terraform {
  backend "s3" {
    bucket = "amalinowski"
    key    = "simple-build/state"
    region = "eu-central-1"
  }
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

resource "aws_eip" "simple-nat-ip" {
  count = "${local.used_azs_count}"
  vpc = true
}

// region NAT GATEWAY

resource "aws_nat_gateway" "simple-nat-gateway" {
  count = "${var.use-nat-gateway == "true" ? local.used_azs_count : 0}"
  allocation_id = "${aws_eip.simple-nat-ip.*.id[count.index]}"
  subnet_id = "${aws_subnet.simple-public.*.id[count.index]}"
  tags {
    Name = "${var.build-tag}-nat-gateway-${count.index}"
  }
}

// endregion

// region NAT BOX

resource "aws_eip_association" "nat-box-eip" {
  count = "${var.use-nat-gateway == "true" ? 0 : local.used_azs_count}"
  instance_id   = "${aws_instance.simple-nat-box.*.id[count.index]}"
  allocation_id = "${aws_eip.simple-nat-ip.*.id[count.index]}"
}

resource "aws_instance" "simple-nat-box" {
  count = "${var.use-nat-gateway == "true" ? 0 : local.used_azs_count}"
  ami = "${var.nat-box-ami}"
  instance_type = "t2.medium"
  subnet_id = "${aws_subnet.simple-public.*.id[count.index]}"
  tags {
    Name = "${var.build-tag}-nat-box-${count.index}"
  }
}

// endregion

//region ROUTE TABLE

resource "aws_route_table" "simple-public-route-table" {
  vpc_id = "${aws_vpc.simple-vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.simple-gw.id}"
  }
  tags {
    Name = "${var.build-tag}-public"
  }
}

resource "aws_route_table_association" "simple-public-association" {
  count = "${local.used_azs_count}"
  route_table_id = "${aws_route_table.simple-public-route-table.id}"
  subnet_id = "${aws_subnet.simple-public.*.id[count.index]}"
}

resource "aws_route_table" "simple-private-route-table" {
  count = "${local.used_azs_count}"
  vpc_id = "${aws_vpc.simple-vpc.id}"

  tags {
    Name = "${var.build-tag}-private-${count.index}"
  }
}

resource "aws_route" "nat-gateway-route" {
  count = "${var.use-nat-gateway == "true" ? local.used_azs_count : 0}"
  route_table_id = "${aws_route_table.simple-private-route-table.*.id[count.index]}"
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = "${aws_nat_gateway.simple-nat-gateway.*.id[count.index]}"
}

resource "aws_route" "nat-instance-route" {
  count = "${var.use-nat-gateway == "true" ? 0 : local.used_azs_count}"
  route_table_id = "${aws_route_table.simple-private-route-table.*.id[count.index]}"
  destination_cidr_block = "0.0.0.0/0"
  instance_id = "${aws_instance.simple-nat-box.*.id[count.index]}"
}

// endregion