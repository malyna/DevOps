data "aws_vpc" "selected" {
  id = "${var.vpc-id}"
}

data "aws_availability_zone" "selected" {
  name = "${var.zone}"
}

locals {
  active-count = "${var.active == "true" ? 1 : 0}"
}

resource "aws_subnet" "simple-public" {
  count = "${local.active-count}"
  cidr_block = "${cidrsubnet(data.aws_vpc.selected.cidr_block, 8, var.index * 10) }"
  vpc_id = "${data.aws_vpc.selected.id}"
  availability_zone = "${data.aws_availability_zone.selected.name}"
  map_public_ip_on_launch = true
  tags {
    Name = "${var.build-tag}-public-${var.index}"
  }
}

resource "aws_subnet" "simple-private" {
  count = "${local.active-count}"
  cidr_block = "${cidrsubnet(data.aws_vpc.selected.cidr_block, 8, var.index * 10 + 1) }"
  vpc_id = "${data.aws_vpc.selected.id}"
  availability_zone = "${data.aws_availability_zone.selected.name}"
  tags {
    Name = "${var.build-tag}-private-${var.index}"
  }
}

resource "aws_subnet" "simple-private-db" {
  count = "${local.active-count}"
  cidr_block = "${cidrsubnet(data.aws_vpc.selected.cidr_block, 8, var.index * 10 + 2) }"
  vpc_id = "${data.aws_vpc.selected.id}"
  availability_zone = "${data.aws_availability_zone.selected.name}"
  tags {
    Name = "${var.build-tag}-private-db-${var.index}"
  }
}

resource "aws_eip" "simple-nat-ip" {
  count = "${local.active-count}"
  vpc = true
}

resource "aws_nat_gateway" "simple-nat-gateway" {
  count = "${var.active == "true" && var.use-nat-gateway == "true" ? 1 : 0}"
  allocation_id = "${aws_eip.simple-nat-ip.id}"
  subnet_id = "${aws_subnet.simple-public.id}"
  tags {
    Name = "${var.build-tag}-nat-gateway-${var.index}"
  }
}

resource "aws_eip_association" "nat-box-eip" {
  count = "${var.active == "true" && var.use-nat-gateway != "true" ? 1 : 0}"
  instance_id   = "${aws_instance.simple-nat-box.*.id[count.index]}"
  allocation_id = "${aws_eip.simple-nat-ip.*.id[count.index]}"
}

resource "aws_instance" "simple-nat-box" {
  count = "${var.active == "true" && var.use-nat-gateway != "true" ? 1 : 0}"
  ami = "${var.nat-box-ami}"
  instance_type = "t2.medium"
  subnet_id = "${aws_subnet.simple-public.id}"
  tags {
    Name = "${var.build-tag}-nat-box-${var.index}"
  }
}

//region ROUTE TABLE

resource "aws_route_table" "simple-public-route-table" {
  count = "${local.active-count}"
  vpc_id = "${data.aws_vpc.selected.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${var.ig-id}"
  }
  tags {
    Name = "${var.build-tag}-public-${var.index}"
  }
}

resource "aws_route_table_association" "simple-public-association" {
  count = "${local.active-count}"
  route_table_id = "${aws_route_table.simple-public-route-table.id}"
  subnet_id = "${aws_subnet.simple-public.id}"
}

resource "aws_route_table" "simple-private-route-table" {
  count = "${local.active-count}"
  vpc_id = "${data.aws_vpc.selected.id}"

  tags {
    Name = "${var.build-tag}-private-${var.index}"
  }
}

resource "aws_route" "nat-gateway-route" {
  count = "${var.active == "true" && var.use-nat-gateway == "true" ? 1 : 0}"
  route_table_id = "${aws_route_table.simple-private-route-table.id}"
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = "${aws_nat_gateway.simple-nat-gateway.id}"
}

resource "aws_route" "nat-instance-route" {
  count = "${var.active == "true" && var.use-nat-gateway != "true" ? 1 : 0}"
  route_table_id = "${aws_route_table.simple-private-route-table.id}"
  destination_cidr_block = "0.0.0.0/0"
  instance_id = "${aws_instance.simple-nat-box.id}"
}

// endregion