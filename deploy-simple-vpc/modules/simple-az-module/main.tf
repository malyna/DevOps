
data "aws_vpc" "selected" {
  id = "${var.vpc_id}"
}

data "aws_availability_zone" "selected" {
  name = "${var.zone_name}"
}

data "aws_internet_gateway" "selected" {
  internet_gateway_id = "${var.ig_id}"
}

locals {
  active = "${var.activate == "true"}"
}

resource "aws_subnet" "simple-public" {
  count = "${local.active ? 1 : 0}"
  cidr_block = "${cidrsubnet(data.aws_vpc.selected.cidr_block, 8, var.index * 10) }"
  vpc_id = "${data.aws_vpc.selected.id}"
  availability_zone = "${data.aws_availability_zone.selected.name}"
  map_public_ip_on_launch = true
  tags {
    Owner = "${var.owner}"
    Name = "${var.owner}-public-${var.name_suffix}"
  }
}

resource "aws_subnet" "simple-private" {
  count = "${local.active ? 1 : 0}"
  cidr_block = "${cidrsubnet(data.aws_vpc.selected.cidr_block, 8, var.index * 10 + 1) }"
  vpc_id = "${data.aws_vpc.selected.id}"
  availability_zone = "${data.aws_availability_zone.selected.name}"
  tags {
    Owner = "${var.owner}"
    Name = "${var.owner}-private-${var.name_suffix}"
  }
}

resource "aws_subnet" "simple-private-db" {
  count = "${local.active ? 1 : 0}"
  cidr_block = "${cidrsubnet(data.aws_vpc.selected.cidr_block, 8, var.index * 10 + 2) }"
  vpc_id = "${data.aws_vpc.selected.id}"
  availability_zone = "${data.aws_availability_zone.selected.name}"
  tags {
    Owner = "${var.owner}"
    Name = "${var.owner}-private-db-${var.name_suffix}"
  }
}

resource "aws_eip" "simple-nat-ip" {
  count = "${local.active ? 1 : 0}"
  vpc = true
}

// region NAT GATEWAY

resource "aws_nat_gateway" "simple-nat-gateway" {
  count = "${local.active && var.use_nat_gateway == "true" ? 1 : 0}"
  allocation_id = "${aws_eip.simple-nat-ip.id}"
  subnet_id = "${aws_subnet.simple-public.id}"
  tags {
    Owner = "${var.owner}"
    Name = "${var.owner}-nat-gateway-${var.name_suffix}"
  }
}

// endregion

// region NAT BOX

resource "aws_eip_association" "nat-box-eip" {
  count = "${local.active && var.use_nat_gateway != "true" ? 1 : 0}"
  instance_id   = "${aws_instance.simple-nat-box.id}"
  allocation_id = "${aws_eip.simple-nat-ip.id}"
}

resource "aws_instance" "simple-nat-box" {
  count = "${local.active && var.use_nat_gateway != "true" ? 1 : 0}"
  ami = "${var.nat_box_ami}"
  instance_type = "t2.medium"
  subnet_id = "${aws_subnet.simple-public.id}"
  tags {
    Name = "${var.owner}-nat-box-${var.name_suffix}"
  }
}

// endregion

//region ROUTE TABLES

resource "aws_route_table" "simple-public-route-table" {
  count = "${local.active ? 1 : 0}"
  vpc_id = "${data.aws_vpc.selected.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${data.aws_internet_gateway.selected.id}"
  }
  tags {
    Owner = "${var.owner}"
    Name = "${var.owner}-public"
  }
}

resource "aws_route_table" "simple-private-route-table" {
  count = "${local.active ? 1 : 0}"
  vpc_id = "${data.aws_vpc.selected.id}"

  tags {
    Owner = "${var.owner}"
    Name = "${var.owner}-private"
  }
}

resource "aws_route" "nat-gateway-route" {
  count = "${local.active && var.use_nat_gateway == "true" ? 1 : 0}"
  route_table_id = "${aws_route_table.simple-private-route-table.id}"
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = "${aws_nat_gateway.simple-nat-gateway.id}"
}

resource "aws_route" "nat-instance-route" {
  count = "${local.active && var.use_nat_gateway != "true" ? 1 : 0}"
  route_table_id = "${aws_route_table.simple-private-route-table.id}"
  destination_cidr_block = "0.0.0.0/0"
  instance_id = "${aws_instance.simple-nat-box.id}"
}

resource "aws_route_table" "simple-private-db-route-table" {
  count = "${local.active ? 1 : 0}"
  vpc_id = "${data.aws_vpc.selected.id}"

  tags {
    Owner = "${var.owner}"
    Name = "${var.owner}-private-db"
  }
}

resource "aws_route_table_association" "simple-public-association" {
  count = "${local.active ? 1 : 0}"
  route_table_id = "${aws_route_table.simple-public-route-table.id}"
  subnet_id = "${aws_subnet.simple-public.id}"
}

resource "aws_route_table_association" "simple-private-association" {
  count = "${local.active ? 1 : 0}"
  route_table_id = "${aws_route_table.simple-private-route-table.id}"
  subnet_id = "${aws_subnet.simple-private.id}"
}

resource "aws_route_table_association" "simple-private-db-association" {
  count = "${local.active ? 1 : 0}"
  route_table_id = "${aws_route_table.simple-private-db-route-table.id}"
  subnet_id = "${aws_subnet.simple-private-db.id}"
}

// endregion