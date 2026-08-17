variable "vpccidr" {
    description = "vpc-cidr"
    type        = string
    default     = "10.0.0.0/16"
}

variable "subcidr" {
    description = "subnet-cidr"
    type        = string
    default     = "10.0.1.0/24"
}

variable "zone" {
    description = "vpc-availability-zone"
    type        = string
    default     = "us-east-1a"
}