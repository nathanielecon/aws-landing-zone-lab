data "aws_partition" "current" {}

locals {
  tags = merge(var.tags, {
    Module = "continuityops-serverless"
  })

  queue_name  = "${var.name_prefix}-worker"
  dlq_name    = "${var.name_prefix}-worker-dlq"
  lambda_name = "${var.name_prefix}-worker"
  lambda_role = "${var.name_prefix}-worker-lambda"
}

resource "aws_sqs_queue" "dlq" {
  name                      = local.dlq_name
  message_retention_seconds = var.sqs_message_retention_seconds

  tags = merge(local.tags, {
    Name = local.dlq_name
    Role = "dlq"
  })
}

resource "aws_sqs_queue" "worker" {
  name                       = local.queue_name
  visibility_timeout_seconds = var.sqs_visibility_timeout_seconds
  message_retention_seconds  = var.sqs_message_retention_seconds

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = var.dlq_max_receive_count
  })

  tags = merge(local.tags, {
    Name = local.queue_name
    Role = "primary"
  })
}

resource "aws_iam_role" "lambda" {
  name = local.lambda_role

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = local.tags
}

resource "aws_iam_role_policy" "lambda_execution" {
  name = "${local.lambda_role}-execution"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        Resource = "arn:${data.aws_partition.current.partition}:logs:*:*:*"
      },
      {
        Sid    = "SqsConsume"
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:ChangeMessageVisibility",
        ]
        Resource = [
          aws_sqs_queue.worker.arn,
          aws_sqs_queue.dlq.arn,
        ]
      },
    ]
  })
}

resource "aws_lambda_function" "worker" {
  function_name = local.lambda_name
  role          = aws_iam_role.lambda.arn
  handler       = var.lambda_handler
  runtime       = var.lambda_runtime
  timeout       = var.lambda_timeout_seconds
  memory_size   = var.lambda_memory_mb

  filename         = var.lambda_package_path
  source_code_hash = filebase64sha256(var.lambda_package_path)

  environment {
    variables = {
      QUEUE_URL = aws_sqs_queue.worker.url
      DLQ_URL   = aws_sqs_queue.dlq.url
    }
  }

  tags = local.tags

  depends_on = [aws_iam_role_policy.lambda_execution]
}

resource "aws_lambda_event_source_mapping" "worker" {
  event_source_arn = aws_sqs_queue.worker.arn
  function_name    = aws_lambda_function.worker.arn
  batch_size       = 10
  enabled          = true
}
