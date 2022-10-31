![GitHub](https://img.shields.io/github/license/brightbock/cloudwatch-logs-retention) ![GitHub release (latest SemVer)](https://img.shields.io/github/v/release/brightbock/cloudwatch-logs-retention) ![GitHub Workflow Status](https://img.shields.io/github/workflow/status/brightbock/cloudwatch-logs-retention/Terraform)

#  CloudWatch Logs Retention

_TLDR: This ensures all CloudWatch Logs log groups will not store logs forever._

This is a Terraform module / AWS [Lambda function](https://github.com/brightbock/cloudwatch-logs-retention/blob/main/src/lambda.py) to ensure Cloudwatch Logs log groups have a [retention policy](https://docs.aws.amazon.com/AmazonCloudWatchLogs/latest/APIReference/API_PutRetentionPolicy.html) configured.

This module will ensure that all log groups are set to retain logs for at least `retention_days_min` and at most `retention_days_max`.

If a log group does not have a retention policy set, or the current retention period is outside of the `retention_days_min` to `retention_days_max` range, then new a retention policy will be applied to the log group, with the retention period set to `retention_days_target` days.

By default `discover_regions` is `true, so log groups in all AWS Regions your account has enabled will be processed.

All log groups will be processed by default. You can specify `regex_match` and `regex_exclude` to process only log groups with names that match `regex_match` and do not match `regex_exclude`.

You can deploy with `dry_run = "true"` to see what will happen without actually changing any log group settings.

The function will be automatically triggered according to the `schedule_expression` [schedule expression](https://docs.aws.amazon.com/lambda/latest/dg/services-cloudwatchevents-expressions.html). The default is to trigger approximately every 23 hours.

## How to use:

1. Add a module definition to your Terraform. See the example below.
2. Update the module configuration to match your requirements, and apply your Terraform.
3. Open the CloudWatch Log log group for this Lambda function to see what it did.

```
module "cloudwatch_logs_retention" {
  project_name          = "cloudwatch_logs_retention"
  source                = "git::https://github.com/brightbock/cloudwatch-logs-retention.git?ref=main"
  # providers             = { aws = aws.use1 }
  retention_days_target = 90
  retention_days_min    = 30
  retention_days_max    = 400
  # discover_regions      = "true"
  # dry_run               = "false"
  # regex_match           = ""
  # regex_exclude         = "^$"
  # schedule_expression   = "rate(23 hours)"
}

```

### Notes:

- Only specific retention periods are accepted by CloudWatch Logs. If you specify `retention_target_days` to a value not on [the list](https://docs.aws.amazon.com/AmazonCloudWatchLogs/latest/APIReference/API_PutRetentionPolicy.html#API_PutRetentionPolicy_RequestSyntax), this Lambda will assume you mean the smallest value on the list that is greater than the number you specified (e.g. `retention_target_days = 380` is taken to mean `retention_target_days = 400`)
- If you want to process one AWS Region only, then set `discover_regions = "false"`, and set `seed_region` to whichever region you want to process e.g. `ap-east-2`
