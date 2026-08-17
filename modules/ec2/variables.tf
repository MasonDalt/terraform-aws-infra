variable "subnet_id" {
  description = "subnet-id"
  type        = string
}

variable "ami" {
  description = "Its ami"
  type        = string
  default     = "ami-12345"
}

variable "instance_type" {
  description = "Its instance-type"
  type        = string
  default     = "t2.micro"
}