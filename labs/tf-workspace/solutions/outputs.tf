output "website_endpoint" {
  description = "Website endpoint for the S3 bucket"
  value       = "http://${aws_s3_bucket.bucket.bucket}.s3-website-${var.region}.amazonaws.com"
}

output "bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.bucket.id
}

output "workspace" {
  description = "Current workspace"
  value       = terraform.workspace
}
