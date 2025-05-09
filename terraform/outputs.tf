# Output values from the Terraform deployment

output "s3_bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.bucket.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.bucket.arn
}

output "alb_dns_name" {
  description = "The DNS name of the load balancer"
  value       = "http://${aws_lb.alb.dns_name}"
}