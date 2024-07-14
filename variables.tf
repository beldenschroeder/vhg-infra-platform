variable "region" {
  description = "AWS region"
  type = string
}

variable "remote_state_bucket" {
  description = "S3 bucket to store Terraform state file"
  type = string
}

variable "remote_state_key" {
  description = "S3 key to store Terraform state file"
  type = string
}

variable "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  type = string
}

# TODO: Consider using later if a solution is found to apply this to `cidr_blocks`s in secruitygroups.tf 
# variable "internet_cidr_blocks" {
#   type = list
#   description = "CIDR blocks to allow internet traffic"
# }

variable "ecs_domain_name" {
  description = "ECS domain name"
  type = string
}