output "name_prefix" {
  description = "Environment name prefix."
  value       = local.name_prefix
}

output "aws_account_id" {
  description = "Configured account ID placeholder (verify before apply)."
  value       = var.aws_account_id
}

output "vpc_id" {
  description = "Staging VPC ID."
  value       = module.network.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs for workloads."
  value       = module.network.private_subnet_ids
}

output "public_subnet_ids" {
  description = "Public subnet IDs."
  value       = module.network.public_subnet_ids
}

output "eks_cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS API endpoint."
  value       = module.eks.cluster_endpoint
}

output "eks_oidc_provider_arn" {
  description = "OIDC provider ARN for IRSA."
  value       = module.eks.oidc_provider_arn
}

output "eks_oidc_provider_url" {
  description = "OIDC provider URL for trust policies."
  value       = module.eks.oidc_provider_url
}

output "worker_queue_url" {
  description = "Primary SQS worker queue URL."
  value       = module.serverless.queue_url
}

output "worker_lambda_arn" {
  description = "Worker Lambda function ARN."
  value       = module.serverless.lambda_function_arn
}

output "log_group_name" {
  description = "Application CloudWatch log group."
  value       = module.observability.log_group_name
}
