variable "vpc_id" {
  type = "string"
}

variable "zone_name" {
  type = "string"
}

variable "ig_id" {
  type = "string"
}

variable "activate" {
  type = "string"
}

variable "owner" {
  type = "string"
}

variable "use_nat_gateway" {
  type = "string"
}

variable "name_suffix" {
  type = "string"
}

variable "nat_box_ami" {
  type = "string"
  default = "no-ami"
}

variable "index" {
  type = "string"
  description = "unique index for module"
}