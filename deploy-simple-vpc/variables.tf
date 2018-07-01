variable "build-tag" {
  type = "string"
  description = "Tag for built resources"
  default = "amalinowski"
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