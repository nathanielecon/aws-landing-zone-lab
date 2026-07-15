# Infrastructure template sketch

Synthetic SAM/CloudFormation fragment for the ContinuityOps SQS worker. Replace
placeholder names per environment; do not commit account-specific identifiers.

## Resources (outline)

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Transform: AWS::Serverless-2016-10-31
Description: ContinuityOps event worker — queue, DLQ, Lambda (lab sketch)

Resources:
  EventsDLQ:
    Type: AWS::SQS::Queue
    Properties:
      QueueName: continuityops-events-dlq
      MessageRetentionPeriod: 1209600

  EventsQueue:
    Type: AWS::SQS::Queue
    Properties:
      QueueName: continuityops-events
      VisibilityTimeout: 180
      RedrivePolicy:
        deadLetterTargetArn: !GetAtt EventsDLQ.Arn
        maxReceiveCount: 5

  EventWorkerFunction:
    Type: AWS::Serverless::Function
    Properties:
      FunctionName: continuityops-event-worker
      Runtime: nodejs20.x
      Handler: index.handler
      Timeout: 30
      MemorySize: 256
      ReservedConcurrentExecutions: 10
      CodeUri: ../src/worker/
      Events:
        EventQueue:
          Type: SQS
          Properties:
            Queue: !GetAtt EventsQueue.Arn
            BatchSize: 10
            FunctionResponseTypes:
              - ReportBatchItemFailures

  DLQDepthAlarm:
    Type: AWS::CloudWatch::Alarm
    Properties:
      AlarmName: continuityops-events-dlq-depth
      MetricName: ApproximateNumberOfMessagesVisible
      Namespace: AWS/SQS
      Dimensions:
        - Name: QueueName
          Value: !GetAtt EventsDLQ.QueueName
      Statistic: Maximum
      Period: 60
      EvaluationPeriods: 5
      Threshold: 1
      ComparisonOperator: GreaterThanOrEqualToThreshold
```

## Operational notes

- **Visibility timeout** — must exceed Lambda timeout × 6; see `sqs-dlq.md`.
- **Reserved concurrency** — start low (10) in lab; raise per environment after
  load testing. Protects shared databases and SaaS export workers.
- **Partial batch responses** — `ReportBatchItemFailures` ensures poison or
  single-record failures do not re-drive successful siblings.
- **Idempotency table (production)** — add `AWS::DynamoDB::Table` with TTL;
  not required for the in-memory lab worker.

Full environment wiring lives under `continuityops/terraform/` in later slices.
