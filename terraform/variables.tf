variable "region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "ap-southeast-3"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "key_name" {
  description = "Name of existing SSH key pair in AWS"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name for resource tagging"
  type        = string
  default     = "chucknoris-jokes"
}

variable "allowed_ssh_cidr" {
  description = "CIDR blocks allowed to SSH into instance. Leave null to auto-detect your current public IP"
  type        = list(string)
  default     = null
}
