data "aws_vpc" "selected" {
  id = "${var.vpc_id}"
}

resource "aws_security_group" "simple-public-sg" {
  name        = "Allow All"
  vpc_id      = "${data.aws_vpc.selected.id}"

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
  vpc_id      = "${data.aws_vpc.selected.id}"

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
  vpc_id      = "${data.aws_vpc.selected.id}"

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