locals {
  tags = merge(var.tags, {
    Module = "continuityops-observability"
  })

  log_group = coalesce(var.log_group_name, "/continuityops/${var.name_prefix}")
}

resource "aws_cloudwatch_log_group" "app" {
  name              = local.log_group
  retention_in_days = var.log_retention_days

  tags = merge(local.tags, {
    Name = local.log_group
  })
}

resource "aws_cloudwatch_metric_alarm" "baseline_errors" {
  alarm_name          = "${var.name_prefix}-baseline-errors"
  alarm_description   = "Baseline error-rate alarm scaffold for ContinuityOps lab workloads."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = var.alarm_metric_name
  namespace           = var.alarm_namespace
  period              = var.alarm_period_seconds
  statistic           = "Sum"
  threshold           = var.alarm_threshold
  treat_missing_data  = "notBreaching"

  alarm_actions = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []

  tags = local.tags
}
