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


module "simple-az-1" {
  source = "./modules/simple-az-module/"
  nat-box-ami = "${var.nat-box-ami}"
  active = "${local.used_azs_count >= 1 ? "true" : "false"}"
  build-tag = "${var.build-tag}"
  index = "0"
  use-nat-gateway = "${var.use-nat-gateway}"
  vpc-id = "${aws_vpc.simple-vpc.id}"
  ig-id = "${aws_internet_gateway.simple-gw.id}"
  zone = "${element(data.aws_availability_zones.available-zones.names, 0)}"
}

module "simple-az-2" {
  source = "./modules/simple-az-module/"
  nat-box-ami = "${var.nat-box-ami}"
  active = "${local.used_azs_count >= 2 ? "true" : "false"}"
  build-tag = "${var.build-tag}"
  index = "1"
  use-nat-gateway = "${var.use-nat-gateway}"
  vpc-id = "${aws_vpc.simple-vpc.id}"
  ig-id = "${aws_internet_gateway.simple-gw.id}"
  zone = "${element(data.aws_availability_zones.available-zones.names, 1)}"
}

module "simple-az-3" {
  source = "./modules/simple-az-module/"
  nat-box-ami = "${var.nat-box-ami}"
  active = "${local.used_azs_count >= 3 ? "true" : "false"}"
  build-tag = "${var.build-tag}"
  index = "2"
  use-nat-gateway = "${var.use-nat-gateway}"
  vpc-id = "${aws_vpc.simple-vpc.id}"
  ig-id = "${aws_internet_gateway.simple-gw.id}"
  zone = "${element(data.aws_availability_zones.available-zones.names, 2)}"
}