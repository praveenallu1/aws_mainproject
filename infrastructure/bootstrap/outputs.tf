output "state_bucket_name" {
  description = "Use this in the workload backend configuration."
  value       = aws_s3_bucket.terraform_state.id
}

output "state_kms_key_arn" {
  description = "KMS key that protects Terraform state."
  value       = aws_kms_key.terraform_state.arn
}

output "backend_configuration" {
  description = "Example backend configuration; select a unique key per environment."
  value       = <<-EOT
    bucket       = "${aws_s3_bucket.terraform_state.id}"
    key          = "cloudops-capstone/dev/terraform.tfstate"
    region       = "${var.aws_region}"
    encrypt      = true
    use_lockfile = true
  EOT
}

