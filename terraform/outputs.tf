output "elastic_ip" {
  description = "Elastic IP address of the EC2 instance"
  value       = aws_eip.web_eip.public_ip
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance (same as Elastic IP)"
  value       = aws_eip.web_eip.public_ip
}

output "instance_public_dns" {
  description = "Public DNS of the EC2 instance"
  value       = aws_instance.web.public_dns
}

output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.web.id
}

output "security_group_id" {
  description = "ID of the security group"
  value       = aws_security_group.web_sg.id
}

output "vpc_id" {
  description = "ID of the default VPC"
  value       = data.aws_vpc.default.id
}

output "subnet_id" {
  description = "ID of the subnet used"
  value       = local.default_subnet_id
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i /path/to/your/private-key.pem ec2-user@${aws_eip.web_eip.public_ip}"
}

output "application_url" {
  description = "URL to access the Chuck Norris Jokes application"
  value       = "http://${aws_eip.web_eip.public_ip}"
}

output "app_files_hash" {
  description = "SHA256 hash of app and docker files (changes trigger re-upload)"
  value       = local.app_files_hash
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket storing app files"
  value       = aws_s3_bucket.app_files.bucket
}
