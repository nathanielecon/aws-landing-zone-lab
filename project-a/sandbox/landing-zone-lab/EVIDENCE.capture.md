# Capture 2026-07-14T20:33:19Z

## sts get-caller-identity
```json
{
    "UserId": "AROAUD2F2BLEIGHQLZJJ4:gha-lzlab-apply-29366105164",
    "Account": "283077380808",
    "Arn": "arn:aws:sts::283077380808:assumed-role/project-a-lzlab-gha/gha-lzlab-apply-29366105164"
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
        "Arn": "arn:aws:iam::283077380808:user/project-a/project-a-lzlab-operator",
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
    "arn:aws:iam::283077380808:role/project-a-lzlab-operator",
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
            "S3BucketName": "project-a-lzlab-archive-283077380808",
            "S3KeyPrefix": "cloudtrail",
            "IncludeGlobalServiceEvents": true,
            "IsMultiRegionTrail": true,
            "HomeRegion": "us-east-1",
            "TrailARN": "arn:aws:cloudtrail:us-east-1:283077380808:trail/project-a-lzlab-trail",
            "LogFileValidationEnabled": true,
            "KmsKeyId": "arn:aws:kms:us-east-1:283077380808:key/a25950f1-8ab7-403b-b137-513445d95783",
            "HasCustomEventSelectors": false,
            "HasInsightSelectors": false,
            "IsOrganizationTrail": false
        }
    ]
}
```

## archive bucket encryption / public access
bucket=project-a-lzlab-archive-283077380808
```
{
    "ServerSideEncryptionConfiguration": {
        "Rules": [
            {
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "aws:kms",
                    "KMSMasterKeyID": "arn:aws:kms:us-east-1:283077380808:key/a25950f1-8ab7-403b-b137-513445d95783"
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
vpc=vpc-0d9b3dae7a4c31563
{
    "FlowLogs": [
        {
            "CreationTime": "2026-07-14T20:28:09.076000+00:00",
            "DeliverLogsStatus": "SUCCESS",
            "FlowLogId": "fl-0dfa827ed78974a93",
            "FlowLogStatus": "ACTIVE",
            "ResourceId": "vpc-0d9b3dae7a4c31563",
            "TrafficType": "ALL",
            "LogDestinationType": "s3",
            "LogDestination": "arn:aws:s3:::project-a-lzlab-archive-283077380808/vpc-flow-logs",
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
    "arn:aws:iam::283077380808:role/workload-audit-writer",
    "arn:aws:iam::283077380808:policy/workload-audit-boundary"
]
{
    "OpenIDConnectProviderList": [
        {
            "Arn": "arn:aws:iam::283077380808:oidc-provider/token.actions.githubusercontent.com"
        }
    ]
}
```
