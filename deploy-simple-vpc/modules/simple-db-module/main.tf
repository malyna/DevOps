resource "aws_db_subnet_group" "simple-db-group" {
  name = "${var.owner}-db"
  subnet_ids = ["${var.db_subnets}"]

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
  name                 = "${var.db_name}"
  username             = "${var.db_user}"
  password             = "${var.db_pass}"
  parameter_group_name = "default.mysql5.7"
  db_subnet_group_name = "${aws_db_subnet_group.simple-db-group.name}"
  vpc_security_group_ids = ["${var.db_sg_ids}"]
  skip_final_snapshot = true
  publicly_accessible = false

  tags {
    Owner = "${var.owner}"
    Name = "${var.owner}-db"
  }
}