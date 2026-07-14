# Capture 2026-07-14T20:33:19Z

## sts get-caller-identity
```json
{
    "UserId": "AROAUD2F2BLEIGHQLZJJ4:gha-lzlab-apply-29366105164",
    "Account": "<AWS_ACCOUNT_ID>",
    "Arn": "arn:aws:sts::<AWS_ACCOUNT_ID>:assumed-role/project-a-lzlab-gha/gha-lzlab-apply-29366105164"
}
```

## GitHub OIDC CI role
```

aws: [ERROR]: An error occurred (NoSuchEntity) when calling the GetRole operation: The role with name GitHubActionsLZLab cannot be found.
```

## operator user/role
```
{
    "User": {
        "Path": "/project-a/",
        "UserName": "project-a-lzlab-operator",
        "UserId": "AIDAUD2F2BLEOVCLVPNVV",
        "Arn": "arn:aws:iam::<AWS_ACCOUNT_ID>:user/project-a/project-a-lzlab-operator",
        "CreateDate": "2026-07-14T20:27:25+00:00",
        "Tags": [
            {
                "Key": "ManagedBy",
                "Value": "terraform"
            },
            {
                "Key": "Project",
                "Value": "project-a"
            },
            {
                "Key": "Environment",
                "Value": "lab"
            },
            {
                "Key": "Owner",
                "Value": "platform"
            },
            {
                "Key": "LabMode",
                "Value": "single-account"
            }
        ]
    }
}
[
    "project-a-lzlab-operator",
    "arn:aws:iam::<AWS_ACCOUNT_ID>:role/project-a-lzlab-operator",
    "2026-07-14T20:27:33+00:00"
]
```

## cloudtrail
```
{
    "IsLogging": true,
    "StartLoggingTime": "2026-07-14T20:28:16.747000+00:00",
    "LatestDeliveryAttemptTime": "",
    "LatestNotificationAttemptTime": "",
    "LatestNotificationAttemptSucceeded": "",
    "LatestDeliveryAttemptSucceeded": "",
    "TimeLoggingStarted": "2026-07-14T20:28:16Z",
    "TimeLoggingStopped": ""
}
{
    "trailList": [
        {
            "Name": "project-a-lzlab-trail",
            "S3BucketName": "project-a-lzlab-archive-<AWS_ACCOUNT_ID>",
            "S3KeyPrefix": "cloudtrail",
            "IncludeGlobalServiceEvents": true,
            "IsMultiRegionTrail": true,
            "HomeRegion": "us-east-1",
            "TrailARN": "arn:aws:cloudtrail:us-east-1:<AWS_ACCOUNT_ID>:trail/project-a-lzlab-trail",
            "LogFileValidationEnabled": true,
            "KmsKeyId": "arn:aws:kms:us-east-1:<AWS_ACCOUNT_ID>:key/<KMS_KEY_ID>",
            "HasCustomEventSelectors": false,
            "HasInsightSelectors": false,
            "IsOrganizationTrail": false
        }
    ]
}
```

## archive bucket encryption / public access
bucket=project-a-lzlab-archive-<AWS_ACCOUNT_ID>
```
{
    "ServerSideEncryptionConfiguration": {
        "Rules": [
            {
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "aws:kms",
                    "KMSMasterKeyID": "arn:aws:kms:us-east-1:<AWS_ACCOUNT_ID>:key/<KMS_KEY_ID>"
                },
                "BucketKeyEnabled": false,
                "BlockedEncryptionTypes": {
                    "EncryptionType": [
                        "SSE-C"
                    ]
                }
            }
        ]
    }
}
{
    "PublicAccessBlockConfiguration": {
        "BlockPublicAcls": true,
        "IgnorePublicAcls": true,
        "BlockPublicPolicy": true,
        "RestrictPublicBuckets": true
    }
}
{
    "Status": "Enabled"
}
```

## vpc + flow logs
```
vpc=vpc-<REDACTED>
{
    "FlowLogs": [
        {
            "CreationTime": "2026-07-14T20:28:09.076000+00:00",
            "DeliverLogsStatus": "SUCCESS",
            "FlowLogId": "fl-<REDACTED>",
            "FlowLogStatus": "ACTIVE",
            "ResourceId": "vpc-<REDACTED>",
            "TrafficType": "ALL",
            "LogDestinationType": "s3",
            "LogDestination": "arn:aws:s3:::project-a-lzlab-archive-<AWS_ACCOUNT_ID>/vpc-flow-logs",
            "LogFormat": "${version} ${account-id} ${interface-id} ${srcaddr} ${dstaddr} ${srcport} ${dstport} ${protocol} ${packets} ${bytes} ${start} ${end} ${action} ${log-status}",
            "Tags": [],
            "MaxAggregationInterval": 600,
            "DestinationOptions": {
                "FileFormat": "plain-text",
                "HiveCompatiblePartitions": false,
                "PerHourPartition": false
            }
        }
    ]
}
```

## identity role + oidc
```
[
    "workload-audit-writer",
    "arn:aws:iam::<AWS_ACCOUNT_ID>:role/workload-audit-writer",
    "arn:aws:iam::<AWS_ACCOUNT_ID>:policy/workload-audit-boundary"
]
{
    "OpenIDConnectProviderList": [
        {
            "Arn": "arn:aws:iam::<AWS_ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
        }
    ]
}
```
