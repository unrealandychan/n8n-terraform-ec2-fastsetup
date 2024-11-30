variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "my-project"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Environment = "dev"
    Project     = "my-project"
    Terraform   = "true"
  }
}

variable "ssl_email" {
  description = "Email for SSL certificate"
  type        = string
  default     = "your-email@example.com"
}

variable "domain_name" {
  description = "Main domain name"
  type        = string
  default     = "example.com"
}

variable "subdomain" {
  description = "Subdomain for n8n"
  type        = string
  default     = "n8n"
}

variable "timezone" {
  description = "Timezone for n8n"
  type        = string
  default     = "UTC"
}
