# n8n Hosting on AWS EC2

This Terraform script provisions an AWS EC2 instance and sets up a Traefik reverse proxy to host n8n.

## Prerequisites

- Terraform CLI installed
- AWS CLI installed
- Docker installed

## Usage

1. Clone this repository:
   ```bash
   git clone https://github.com/your-repo.git
   ```

2. Navigate to the project directory:
   ```bash
   cd n8n-hosting
   ```

3. Initialize Terraform:
   ```bash
   terraform init
   ```

4. Apply the Terraform configuration:
   ```bash
   terraform apply
   ```

5. Follow the prompts to confirm the creation of the resources.

6. Once the resources are created, you can find the SSH connection string in the Terraform output. Use it to connect to your EC2 instance.

## Notes

- This script assumes that you have a domain name and a SSL certificate. If you don't have a domain name, you can use AWS Route 53 to register one.

