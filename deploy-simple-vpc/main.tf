terraform {
  backend "s3" {
    bucket = "amalinowski"
    key    = "simple-deploy/deploy"
    region = "eu-central-1"
    profile = "artur-dev"
  }
}

provider "aws" {
  region = "${var.region}"
  profile = "${var.user_profile}"
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

data "aws_availability_zone" "zone-1" {
  name = "${data.aws_availability_zones.all-zones.names[0]}"
}

data "aws_availability_zone" "zone-2" {
  name = "${data.aws_availability_zones.all-zones.names[1]}"
}

data "aws_availability_zone" "zone-3" {
  name = "${data.aws_availability_zones.all-zones.names[2]}"
}

locals {
  available_zone_count = "${length(data.aws_availability_zones.all-zones.names)}"
  zone_required_state = "available"
}

module "simple-module-1" {
  source = "./modules/simple-az-module/"
  owner = "${var.owner}"
  name_suffix = "module1"
  index = "0"
  activate = "${local.available_zone_count > 0 && data.aws_availability_zone.zone-1.state == local.zone_required_state ? "true" : "false"}"
  vpc_id = "${aws_vpc.simple-vpc.id}"
  az_name = "${data.aws_availability_zone.zone-1.name}"
  public_route_table_id = "${aws_route_table.simple-public-route-table.id}"
  use_nat_gateway = "${var.use-nat-gateway}"
  nat_box_ami = "${var.nat-box-ami}"
}

module "simple-module-2" {
  source = "./modules/simple-az-module/"
  owner = "${var.owner}"
  name_suffix = "module2"
  index = "1"
  activate = "${local.available_zone_count > 1 && data.aws_availability_zone.zone-2.state == local.zone_required_state ? "true" : "false"}"
  vpc_id = "${aws_vpc.simple-vpc.id}"
  az_name = "${data.aws_availability_zone.zone-2.name}"
  public_route_table_id = "${aws_route_table.simple-public-route-table.id}"
  use_nat_gateway = "${var.use-nat-gateway}"
  nat_box_ami = "${var.nat-box-ami}"
}

module "simple-module-3" {
  source = "./modules/simple-az-module/"
  owner = "${var.owner}"
  name_suffix = "module3"
  index = "2"
  activate = "${local.available_zone_count > 2 && data.aws_availability_zone.zone-3.state == local.zone_required_state ? "true" : "false"}"
  vpc_id = "${aws_vpc.simple-vpc.id}"
  az_name = "${data.aws_availability_zone.zone-3.name}"
  public_route_table_id = "${aws_route_table.simple-public-route-table.id}"
  use_nat_gateway = "${var.use-nat-gateway}"
  nat_box_ami = "${var.nat-box-ami}"
}

resource "aws_route_table" "simple-public-route-table" {
  vpc_id = "${aws_vpc.simple-vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.simple-gw.id}"
  }
  tags {
    Owner = "${var.owner}"
    Name = "${var.owner}-public"
  }
}

resource "aws_security_group" "simple-public-sg" {
  name        = "Allow All"
  vpc_id      = "${aws_vpc.simple-vpc.id}"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags {
    Owner = "${var.owner}"
    Name = "${var.owner}-public-sg"
  }
}

resource "aws_security_group" "simple-private-sg" {
  name        = "Allow Http"
  vpc_id      = "${aws_vpc.simple-vpc.id}"

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "6"
    security_groups = ["${aws_security_group.simple-public-sg.id}"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags {
    Owner = "${var.owner}"
    Name = "${var.owner}-private-sg"
  }
}

resource "aws_security_group" "simple-db-sg" {
  name        = "db_access_sg"
  description = "Allow all inbound traffic"
  vpc_id      = "${aws_vpc.simple-vpc.id}"

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "6"
    security_groups = ["${aws_security_group.simple-private-sg.id}"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags {
    Owner = "${var.owner}"
    Name = "${var.owner}-db-sg"
  }
}


resource "aws_db_subnet_group" "simple-db-group" {
  name = "${var.owner}-db"
  subnet_ids = [
    "${module.simple-module-1.db_subnet_id}",
    "${module.simple-module-2.db_subnet_id}",
    "${module.simple-module-3.db_subnet_id}"
  ]
  tags {
    Owner = "${var.owner}"
    Name = "${var.owner}-db-group"
  }
}

resource "aws_db_instance" "simple-db" {
  allocated_storage    = 10
  storage_type         = "gp2"
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.t2.micro"
  name                 = "testdb"
  username             = "test1234"
  password             = "test1234"
  parameter_group_name = "default.mysql5.7"
  db_subnet_group_name = "${aws_db_subnet_group.simple-db-group.name}"
  vpc_security_group_ids = ["${aws_security_group.simple-db-sg.id}"]
  skip_final_snapshot = true
  publicly_accessible = false

  tags {
    Owner = "${var.owner}"
    Name = "${var.owner}-db"
  }
}