variable "owner" {
  type = "string"
}

variable "region" {
  type = "string"
}

variable "user_profile" {
  type = "string"
}

variable "use-nat-gateway" {
  type = "string"
  default = "true"
}

variable "nat-box-ami" {
  type = "string"
}

variable "db_name" {
  type = "string"
}

variable "db_user" {
  type = "string"
}

variable "db_pass" {
  type = "string"
}