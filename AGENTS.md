# Chuck Norris Jokes - AI Development Guidelines

## Build Commands

### Application (Local)
```bash
cd app
python -m venv venv && source venv/bin/activate
pip install -r requirements.txt
python server.py
```

### Docker
```bash
cd app
docker build -f ../docker/Dockerfile -t chucknoris-jokes .
docker run -p 5000:5000 chucknoris-jokes

docker-compose up -d    # Start containers
docker-compose down     # Stop containers
docker-compose logs -f  # View logs
```

### Terraform
```bash
cd terraform
terraform init          # Initialize
terraform plan          # Preview changes
terraform apply         # Deploy
terraform destroy       # Cleanup
terraform output        # Get outputs
```

### Testing
No test framework configured. To add tests:
```bash
pip install pytest pytest-cov
pytest                  # Run all tests
pytest tests/test_file.py -k test_name    # Run single test
pytest -v --cov=app    # Run with coverage
```

## Code Style Guidelines

### Python
- **Imports**: Standard library first, third-party, local modules
- **Naming**: snake_case for functions/variables, PascalCase for classes
- **Formatting**: 4-space indentation, no trailing whitespace
- **Constants**: UPPER_CASE with underscores
- **Error Handling**: Specific exceptions first, generic Exception last
- **Docstrings**: Google style (not required in this project)
- **Line Length**: Max 100 characters

### Terraform
- **Resources**: snake_case, descriptive names
- **Variables**: snake_case, include type and description
- **Outputs**: snake_case, include description
- **File Paths**: Always use `${path.module}` prefix for relative paths
- **Naming Pattern**: `<project>-<resource>-<environment>`
- **Dependencies**: Use `depends_on`, not `time_sleep` or triggers for sequencing

### Docker
- **Base Images**: Official images (Alpine preferred)
- **Multi-stage**: Use for smaller final images
- **Commands**: Use array syntax `CMD ["executable", "arg"]`
- **User**: Run as non-root user when possible

### HTML/CSS
- **HTML**: Semantic elements, lowercase tags
- **CSS**: lowercase selectors, consistent spacing (2-4 spaces)
- **Responsive**: Use media queries for mobile

## Critical DevOps Rules

1. **NEVER delete `.terraform/` folder** - Contains provider binaries
2. **NEVER delete `.tfstate` or `.terraform.lock.hcl`** - State tracking
3. **NEVER commit secrets** - `.env`, `terraform.tfvars`, `*.pem`, `*.key`
4. **Use `${path.module}`** for all relative paths in Terraform
5. **Clean up AWS resources** before re-apply to avoid conflicts
6. **SSM parameters** must be PascalCase (alphanumeric only)
7. **IAM policies** - Follow least privilege principle
8. **Security groups** - Auto-detect deployer IP, use `targets` not `instance_id`

## File Change Detection

Modifying `app/` or `docker/` files triggers auto-redeploy via SHA256 hash:
- Update `locals.app_files_hash` when adding new source files
- Terraform re-uploads to S3 and re-runs SSM Document automatically
- Manual trigger: `terraform taint null_resource.upload_app_files`

## Security Best Practices

- S3 buckets: AES256 encryption, versioning enabled
- EC2: Encrypted EBS volumes, IAM instance profile
- No hardcoded secrets, use variables with `.tfvars.example`
- SSH restricted to deployer IP via security group
