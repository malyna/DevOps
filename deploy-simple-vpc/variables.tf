variable "build-tag" {
  type = "string"
  description = "Tag for built resources"
  default = "amalinowski"
}

variable "owner" {
  type = "string"
}

variable "region" {
  type = "string"
}

variable "access-key" {
  type = "string"
}

variable "secret-key" {
  type = "string"
}

variable "use-nat-gateway" {
  type = "string"
  default = "true"
}

variable "nat-box-ami" {
  type = "string"
}