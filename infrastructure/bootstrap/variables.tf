variable "aws_region" {
  description = "AWS Region that stores Terraform state."
  type        = string
  default     = "ap-southeast-2"
}

variable "project_name" {
  description = "Short project identifier used in resource names and tags."
  type        = string
  default     = "cloudops-capstone"
}

variable "state_bucket_name" {
  description = "Optional globally unique bucket name. A suffix is generated when null."
  type        = string
  default     = null
}

variable "owner" {
  description = "Owner tag for cost allocation."
  type        = string
  default     = "portfolio"
}

