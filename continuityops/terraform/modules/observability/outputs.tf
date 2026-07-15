output "log_group_name" {
  description = "CloudWatch log group name."
  value       = aws_cloudwatch_log_group.app.name
}

output "log_group_arn" {
  description = "CloudWatch log group ARN."
  value       = aws_cloudwatch_log_group.app.arn
}

output "baseline_alarm_name" {
  description = "Baseline metric alarm name."
  value       = aws_cloudwatch_metric_alarm.baseline_errors.alarm_name
}

output "baseline_alarm_arn" {
  description = "Baseline metric alarm ARN."
  value       = aws_cloudwatch_metric_alarm.baseline_errors.arn
}
