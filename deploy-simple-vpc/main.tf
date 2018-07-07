terraform {
  backend "s3" {
    bucket = "amalinowski"
    key    = "simple-build/state"
    region = "eu-central-1"
  }
}

provider "aws" {
  region = "${var.region}"
  access_key = "${var.access-key}"
  secret_key = "${var.secret-key}"
}

resource "aws_vpc" "simple-vpc" {
  cidr_block = "10.0.0.0/16"
  tags {
    Owner = "${var.owner}"
    Name = "${var.owner}-vpc"
  }
}

resource "aws_internet_gateway" "simple-gw" {
  vpc_id = "${aws_vpc.simple-vpc.id}"
  tags {
    Owner = "${var.owner}"
    Name = "${var.owner}-igw"
  }
}

data "aws_availability_zones" "all-zones" {}

locals {
  available_zone_count = "${length(data.aws_availability_zones.all-zones.names)}"
  zone_required_state = "available"
}

module "simple-module-1" {
  source = "./modules/simple-az-module/"
  owner = "${var.owner}"
  name_suffix = "module1"
  index = "0"
  activate = "${local.available_zone_count > 0 && element(data.aws_availability_zones.all-zones.state, 0) == local.zone_required_state ? "true" : "false"}"
  vpc_id = "${aws_vpc.simple-vpc.id}"
  ig_id = "${aws_internet_gateway.simple-gw.id}"
  zone_name = "${element(data.aws_availability_zones.all-zones.names, 0)}"
  use_nat_gateway = "${var.use-nat-gateway}"
  nat_box_ami = "${var.nat-box-ami}"
}

module "simple-module-2" {
  source = "./modules/simple-az-module/"
  owner = "${var.owner}"
  name_suffix = "module2"
  index = "1"
  activate = "${local.available_zone_count > 1 && element(data.aws_availability_zones.all-zones.state, 1) == local.zone_required_state ? "true" : "false"}"
  vpc_id = "${aws_vpc.simple-vpc.id}"
  ig_id = "${aws_internet_gateway.simple-gw.id}"
  zone_name = "${element(data.aws_availability_zones.all-zones.names, 1)}"
  use_nat_gateway = "${var.use-nat-gateway}"
  nat_box_ami = "${var.nat-box-ami}"
}

module "simple-module-3" {
  source = "./modules/simple-az-module/"
  owner = "${var.owner}"
  name_suffix = "module3"
  index = "2"
  activate = "${local.available_zone_count > 2 && element(data.aws_availability_zones.all-zones.state, 2) == local.zone_required_state ? "true" : "false"}"
  vpc_id = "${aws_vpc.simple-vpc.id}"
  ig_id = "${aws_internet_gateway.simple-gw.id}"
  zone_name = "${element(data.aws_availability_zones.all-zones.names, 2)}"
  use_nat_gateway = "${var.use-nat-gateway}"
  nat_box_ami = "${var.nat-box-ami}"
}