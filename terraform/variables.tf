variable "region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "ap-southeast-3"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.nano"
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

variable "s3_object_name" {
  description = "Name of the S3 object containing the application files archive"
  type        = string
  default     = "app-files.tar.gz"
}

variable "ssh_private_key_path" {
  description = "Path to the SSH private key for connecting to the EC2 instance"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where resources will be deployed. Leave null to use default VPC"
  type        = string
  default     = null
}

variable "subnet_id" {
  description = "Subnet ID where EC2 instance will be deployed. Leave null to auto-select public subnet with IGW route"
  type        = string
  default     = null
}
