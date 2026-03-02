region        = "ap-southeast-3"
instance_type = "t2.micro"
key_name      = "your-existing-key-pair-name" # Replace with your actual key pair name
environment   = "dev"
project_name  = "chucknoris-jokes"

# Leave null to auto-detect your current public IP for SSH access
allowed_ssh_cidr = null
