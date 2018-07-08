output "db_subnet_id" {
  value = "${aws_subnet.simple-private-db.*.id[0]}"
}