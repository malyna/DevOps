
data "aws_vpc" "selected" {
  id = "${var.vpc_id}"
}

data "aws_availability_zone" "selected" {
  name = "${var.az_name}"
}

data "aws_route_table" "simple-public" {
  route_table_id = "${var.public_route_table_id}"
}

locals {
  active = "${var.activate == "true" ? 1 : 0}"
  use_nat_box = "${var.activate == "true" && var.use_nat_gateway != "true" ? 1 : 0}"
  use_nat_gateway = "${var.activate == "true" && var.use_nat_gateway == "true" ? 1 : 0}"
}

// region SUBNETS

resource "aws_subnet" "simple-public" {
  count = "${local.active}"
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
  count = "${local.active}"
  cidr_block = "${cidrsubnet(data.aws_vpc.selected.cidr_block, 8, var.index * 10 + 1) }"
  vpc_id = "${data.aws_vpc.selected.id}"
  availability_zone = "${data.aws_availability_zone.selected.name}"
  tags {
    Owner = "${var.owner}"
    Name = "${var.owner}-private-${var.name_suffix}"
  }
}

resource "aws_subnet" "simple-private-db" {
  count = "${local.active}"
  cidr_block = "${cidrsubnet(data.aws_vpc.selected.cidr_block, 8, var.index * 10 + 2) }"
  vpc_id = "${data.aws_vpc.selected.id}"
  availability_zone = "${data.aws_availability_zone.selected.name}"
  tags {
    Owner = "${var.owner}"
    Name = "${var.owner}-private-db-${var.name_suffix}"
  }
}

// endregion

resource "aws_eip" "simple-nat-ip" {
  count = "${local.active}"
  vpc = true

  tags {
    Owner = "${var.owner}"
    Name = "${var.owner}-eip-${var.name_suffix}"
  }
}

// region NAT GATEWAY

resource "aws_nat_gateway" "simple-nat-gateway" {
  count = "${local.use_nat_gateway}"
  allocation_id = "${aws_eip.simple-nat-ip.id}"
  subnet_id = "${aws_subnet.simple-public.id}"
  tags {
    Owner = "${var.owner}"
    Name = "${var.owner}-nat-gateway-${var.name_suffix}"
  }
}

// endregion

// region NAT BOX

resource "aws_security_group" "simple-nat-box-sg" {
  count = "${local.use_nat_box}"
  name        = "Allow Http to NAT - ${var.name_suffix}"
  vpc_id      = "${data.aws_vpc.selected.id}"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "6"
    cidr_blocks = ["${aws_subnet.simple-private.cidr_block}"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags {
    Owner = "${var.owner}"
    Name = "${var.owner}-nat-box-sg"
  }
}

resource "aws_security_group_rule" "allow_443_in" {
  count           = "${local.use_nat_box}"
  type            = "ingress"
  from_port       = 443
  to_port         = 443
  protocol        = "tcp"
  cidr_blocks     = ["${aws_subnet.simple-private.cidr_block}"]
  security_group_id = "${aws_security_group.simple-nat-box-sg.id}"
}

resource "aws_eip_association" "nat-box-eip" {
  count           = "${local.use_nat_box}"
  instance_id   = "${aws_instance.simple-nat-box.id}"
  allocation_id = "${aws_eip.simple-nat-ip.id}"
}

resource "aws_instance" "simple-nat-box" {
  count           = "${local.use_nat_box}"
  ami = "${var.nat_box_ami}"
  instance_type = "t2.micro"
  subnet_id = "${aws_subnet.simple-public.id}"
  source_dest_check = false
  vpc_security_group_ids = ["${aws_security_group.simple-nat-box-sg.id}"]
  tags {
    Name = "${var.owner}-nat-box-${var.name_suffix}"
  }
}

// endregion

//region ROUTE TABLES

resource "aws_route_table" "simple-private" {
  count = "${local.active}"
  vpc_id = "${data.aws_vpc.selected.id}"

  tags {
    Owner = "${var.owner}"
    Name = "${var.owner}-private-${var.name_suffix}"
  }
}

resource "aws_route" "nat-gateway-route" {
  count = "${local.active && var.use_nat_gateway == "true" ? 1 : 0}"
  route_table_id = "${aws_route_table.simple-private.id}"
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = "${aws_nat_gateway.simple-nat-gateway.id}"
}

resource "aws_route" "nat-instance-route" {
  count = "${local.active && var.use_nat_gateway != "true" ? 1 : 0}"
  route_table_id = "${aws_route_table.simple-private.id}"
  destination_cidr_block = "0.0.0.0/0"
  instance_id = "${aws_instance.simple-nat-box.id}"
}

resource "aws_route_table_association" "simple-public-association" {
  count = "${local.active}"
  route_table_id = "${data.aws_route_table.simple-public.id}"
  subnet_id = "${aws_subnet.simple-public.id}"
}

resource "aws_route_table_association" "simple-private-association" {
  count = "${local.active}"
  route_table_id = "${aws_route_table.simple-private.id}"
  subnet_id = "${aws_subnet.simple-private.id}"
}

// endregion