variable "vpc_name" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "public_subnet_cidrs" {
  type = list(string)
}

variable "private_app_subnet_cidrs" {
  type = list(string)
}

variable "private_ai_subnet_cidrs" {
  type = list(string)
}

#variable "availability_zone" {
#  type = string
#}
