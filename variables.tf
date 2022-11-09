##############################################################################
# Variables File
#
# Here is where we store the default values for all the variables used in our
# Terraform code. If you create a variable with no default, the user will be
# prompted to enter it (or define it via config file or command line flags.)

variable "prefix" {
  description = "This prefix will be included in the name of most resources."
  default     = "hashicups-workload"
}
variable "environment" {
  description = "Specifies the environment type. e.g. dev, stg, prd."
  default     = "dev"
}

variable "region" {
  description = "The region where the resources are created."
  default     = "ap-southeast-1"
}

variable "instance_type" {
  description = "Specifies the AWS instance type."
  default     = "t2.micro"
}

variable "keypair" {
  description = "Specifies the EC2 keypair. It not specified, it creates a new keypair."
  default = null
}
