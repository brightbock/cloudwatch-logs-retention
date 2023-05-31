![GitHub](https://img.shields.io/github/license/brightbock/cloudwatch-logs-retention) ![GitHub release (latest SemVer)](https://img.shields.io/github/v/release/brightbock/cloudwatch-logs-retention) ![GitHub Workflow Status](https://img.shields.io/github/actions/workflow/status/brightbock/cloudwatch-logs-retention/terraform.yml?branch=main)

#  CloudWatch Logs Retention

_TLDR: This ensures all CloudWatch Logs log groups will not store logs forever._

This is a Terraform module / AWS [Lambda function](https://github.com/brightbock/cloudwatch-logs-retention/blob/main/src/lambda.py) to ensure CloudWatch Logs log groups have a [retention policy](https://docs.aws.amazon.com/AmazonCloudWatchLogs/latest/APIReference/API_PutRetentionPolicy.html) configured.

This module will ensure that all log groups are set to retain logs for at least `retention_days_min` and at most `retention_days_max`.

If a log group does not have a retention policy set, or the current retention period is outside of the `retention_days_min` to `retention_days_max` range, then new a retention policy will be applied to the log group, with the retention period set to `retention_days_target` days.

By default `discover_regions` is `true`, so log groups in all AWS Regions will be processed.

All log groups will be processed by default. You can specify `regex_match` and `regex_exclude` to process only log groups with names that match `regex_match` and do not match `regex_exclude`.

You can deploy with `dry_run = "true"` to see what will happen without actually changing any log group settings.

The function will be automatically triggered according to the `schedule_expression` [schedule expression](https://docs.aws.amazon.com/lambda/latest/dg/services-cloudwatchevents-expressions.html). The default is to trigger approximately every 23 hours.

Setting `delete_empty_days` to a positive integer will delete _empty_ log groups older than that number of days.

## How to use:

1. Add a module definition to your Terraform. See the example below.
2. Update the module configuration to match your requirements, and apply your Terraform.
3. Open the CloudWatch Log log group for this Lambda function to see what it did.

```
module "cloudwatch_logs_retention" {
  project_name          = "cloudwatch_logs_retention"
  source                = "git::https://github.com/brightbock/cloudwatch-logs-retention.git?ref=v0.2.3"
  # providers             = { aws = aws.use1 }
  retention_days_target = 90
  retention_days_min    = 30
  retention_days_max    = 400
  # discover_regions      = "true"
  # dry_run               = "false"
  # regex_match           = ""
  # regex_exclude         = "^$"
  # schedule_expression   = "rate(23 hours)"
  # delete_empty_days     = 600
}

```

### Notes:

- Only specific retention periods are accepted by CloudWatch Logs. If you specify `retention_target_days` to a value not on [the list](https://docs.aws.amazon.com/AmazonCloudWatchLogs/latest/APIReference/API_PutRetentionPolicy.html#API_PutRetentionPolicy_RequestSyntax), this Lambda will assume you mean the smallest value on the list that is greater than the number you specified (e.g. `retention_target_days = 380` is taken to mean `retention_target_days = 400`)
- If you want to process one AWS Region only, then set `discover_regions = "false"`, and set `seed_region` to whichever region you want to process e.g. `ap-east-2`.
- If this Lambda runs for about 20-30 seconds each day, the annual cost will be less than $0.02 USD - Lambda (Arm) in Oregon region, at $0.0000017 USD per second.

### Example Log:

The Lambda found 17 regions, hosting a total of 392 log groups. 353 log groups had names that did not match the name filter regex, so were skipped. In `us-west-2` there was one log group `/aws/lambda/cloudwatch_logs_retention_lambda` with a `1 day` retention policy, that was changed to a `90 days` retention policy.

(If you run with `dry_run = "true"`, all log groups will be shown, not just the ones that were updated)

```
START RequestId: f9d6178f-5e25-4caa-9441-09c59291d151 Version: $LATEST
==== [0001/0017] REGION: ap-northeast-1
==== [0002/0017] REGION: ap-northeast-2
==== [0003/0017] REGION: ap-northeast-3
==== [0004/0017] REGION: ap-south-1
==== [0005/0017] REGION: ap-southeast-1
==== [0006/0017] REGION: ap-southeast-2
==== [0007/0017] REGION: ca-central-1
==== [0008/0017] REGION: eu-central-1
==== [0009/0017] REGION: eu-north-1
==== [0010/0017] REGION: eu-west-1
==== [0011/0017] REGION: eu-west-2
==== [0012/0017] REGION: eu-west-3
==== [0013/0017] REGION: sa-east-1
==== [0014/0017] REGION: us-east-1
==== [0015/0017] REGION: us-east-2
==== [0016/0017] REGION: us-west-1
==== [0017/0017] REGION: us-west-2
== [us-west-2] CHANGE [FROM:0001 TO:0090] /aws/lambda/cloudwatch_logs_retention_lambda
==== SUMMARY: Regions:17, LogGroups:392, Filtered:353, Changed:1 ====
END RequestId: f9d6178f-5e25-4caa-9441-09c59291d151
REPORT RequestId: f9d6178f-5e25-4caa-9441-09c59291d151	Duration: 18844.06 ms	Billed Duration: 18845 ms	Memory Size: 128 MB	Max Memory Used: 79 MB	Init Duration: 242.07 ms
```
