terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-west-2"  # Change this to your preferred region
}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "main-vpc"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${data.aws_region.current.name}a"

  tags = {
    Name = "public-subnet"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "public-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

data "aws_region" "current" {}

resource "aws_security_group" "ec2_sg" {
  name        = "${var.project_name}-security-group"
  description = "Security group for EC2 instance"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-security-group"
    }
  )
}

resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key" {
  key_name   = "${var.project_name}-key"
  public_key = tls_private_key.ssh.public_key_openssh
}

resource "local_file" "private_key" {
  content  = tls_private_key.ssh.private_key_pem
  filename = "${var.project_name}-key.pem"

  provisioner "local-exec" {
    command = "chmod 400 ${var.project_name}-key.pem"
  }
}

data "aws_ami" "amazon_linux_2" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["amazon"] # Amazon
}

resource "aws_instance" "web" {
  ami           = data.aws_ami.amazon_linux_2.id
  instance_type = var.instance_type

  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.ec2_sg.id]
  key_name                    = aws_key_pair.generated_key.key_name
  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              # Update system packages
              yum update -y

              # Install Git
              yum install -y git

              # Install Docker
              yum install -y docker
              systemctl start docker
              systemctl enable docker

              # Install Docker Compose
              curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
              chmod +x /usr/local/bin/docker-compose

              # Add ec2-user to docker group
              usermod -aG docker ec2-user

              # Create a directory for the project
              mkdir -p /home/ec2-user/n8n
              cd /home/ec2-user/n8n

              # Create .env file
              cat > /home/ec2-user/n8n/.env <<'EOL'
              SSL_EMAIL=${var.ssl_email}
              DOMAIN_NAME=${var.domain_name}
              SUBDOMAIN=${var.subdomain}
              GENERIC_TIMEZONE=${var.timezone}
              EOL

              # Create docker-compose.yml
              cat > /home/ec2-user/n8n/docker-compose.yml <<'EOL'
              version: "3.7"

              services:
                traefik:
                  image: "traefik"
                  restart: always
                  command:
                    - "--api=true"
                    - "--api.insecure=true"
                    - "--providers.docker=true"
                    - "--providers.docker.exposedbydefault=false"
                    - "--entrypoints.web.address=:80"
                    - "--entrypoints.web.http.redirections.entryPoint.to=websecure"
                    - "--entrypoints.web.http.redirections.entrypoint.scheme=https"
                    - "--entrypoints.websecure.address=:443"
                    - "--certificatesresolvers.mytlschallenge.acme.tlschallenge=true"
                    - "--certificatesresolvers.mytlschallenge.acme.email=\${SSL_EMAIL}"
                    - "--certificatesresolvers.mytlschallenge.acme.storage=/letsencrypt/acme.json"
                  ports:
                    - "80:80"
                    - "443:443"
                  volumes:
                    - traefik_data:/letsencrypt
                    - /var/run/docker.sock:/var/run/docker.sock:ro

                n8n:
                  image: docker.n8n.io/n8nio/n8n
                  restart: always
                  ports:
                    - "127.0.0.1:5678:5678"
                  labels:
                    - traefik.enable=true
                    - traefik.http.routers.n8n.rule=Host(\${SUBDOMAIN}.\${DOMAIN_NAME})
                    - traefik.http.routers.n8n.tls=true
                    - traefik.http.routers.n8n.entrypoints=web,websecure
                    - traefik.http.routers.n8n.tls.certresolver=mytlschallenge
                    - traefik.http.middlewares.n8n.headers.SSLRedirect=true
                    - traefik.http.middlewares.n8n.headers.STSSeconds=315360000
                    - traefik.http.middlewares.n8n.headers.browserXSSFilter=true
                    - traefik.http.middlewares.n8n.headers.contentTypeNosniff=true
                    - traefik.http.middlewares.n8n.headers.forceSTSHeader=true
                    - traefik.http.middlewares.n8n.headers.SSLHost=\${DOMAIN_NAME}
                    - traefik.http.middlewares.n8n.headers.STSIncludeSubdomains=true
                    - traefik.http.middlewares.n8n.headers.STSPreload=true
                    - traefik.http.routers.n8n.middlewares=n8n@docker
                  environment:
                    - N8N_HOST=\${SUBDOMAIN}.\${DOMAIN_NAME}
                    - N8N_PORT=5678
                    - N8N_PROTOCOL=https
                    - NODE_ENV=production
                    - WEBHOOK_URL=https://\${SUBDOMAIN}.\${DOMAIN_NAME}/
                    - GENERIC_TIMEZONE=\${GENERIC_TIMEZONE}
                  volumes:
                    - n8n_data:/home/node/.n8n

              volumes:
                traefik_data:
                  external: true
                n8n_data:
                  external: true
              EOL

              # Create volumes
              docker volume create traefik_data
              docker volume create n8n_data

              # Set proper ownership
              chown -R ec2-user:ec2-user /home/ec2-user/n8n

              # Start the services
              cd /home/ec2-user/n8n
              docker-compose up -d
              EOF

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-web-server"
    }
  )
}

output "ssh_connection_string" {
  description = "SSH connection string for the EC2 instance"
  value       = "ssh -i ec2-key.pem ec2-user@${aws_instance.web.public_ip}"
}
