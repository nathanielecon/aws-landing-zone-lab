output "queue_url" {
  description = "Primary SQS queue URL."
  value       = aws_sqs_queue.worker.url
}

output "queue_arn" {
  description = "Primary SQS queue ARN."
  value       = aws_sqs_queue.worker.arn
}

output "dlq_url" {
  description = "Dead-letter queue URL."
  value       = aws_sqs_queue.dlq.url
}

output "dlq_arn" {
  description = "Dead-letter queue ARN."
  value       = aws_sqs_queue.dlq.arn
}

output "lambda_function_name" {
  description = "Lambda function name."
  value       = aws_lambda_function.worker.function_name
}

output "lambda_function_arn" {
  description = "Lambda function ARN."
  value       = aws_lambda_function.worker.arn
}

output "lambda_role_arn" {
  description = "IAM role ARN assumed by the Lambda function."
  value       = aws_iam_role.lambda.arn
}

output "lambda_role_name" {
  description = "IAM role name assumed by the Lambda function."
  value       = aws_iam_role.lambda.name
}
