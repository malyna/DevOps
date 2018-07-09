output "public_sg_id" {
  value = "${aws_security_group.simple-public-sg.id}"
}

output "private_sg_id" {
  value = "${aws_security_group.simple-private-sg.id}"
}

output "private_db_sg_id" {
  value = "${aws_security_group.simple-db-sg.id}"
}
