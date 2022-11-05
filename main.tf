locals {
  # Abstracting out let's us create the lambda_logs log group even before the function exists
  lambda_function_name = "${var.project_name}_lambda"
  lambda_function_environment = {
    RETENTION_DAYS_TARGET         = var.retention_days_target
    RETENTION_DAYS_MIN            = var.retention_days_min
    RETENTION_DAYS_MAX            = var.retention_days_max
    DELETE_EMPTY_DAYS             = var.delete_empty_days
    CACHE_TTL_SECONDS_REGION_LIST = var.cache_ttl_seconds_region_list
    SEED_REGION                   = var.seed_region == "" ? data.aws_region.current.name : var.seed_region
    DISCOVER_REGIONS              = var.discover_regions ? "true" : "false"
    DRY_RUN                       = var.dry_run ? "true" : "false"
    REGEX_MATCH                   = var.regex_match
    REGEX_EXCLUDE                 = var.regex_exclude
  }
  lambda_function_env_hash = sha256(jsonencode(local.lambda_function_environment))
  lambda_src_dir           = var.lambda_src_dir == "" ? "${path.module}/src" : var.lambda_src_dir
}

data "aws_region" "current" {}

resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${local.lambda_function_name}"
  retention_in_days = var.lambda_log_retention_in_days

  # Yield to our lambda function
  lifecycle {
    ignore_changes = [retention_in_days]
  }
}

resource "aws_iam_role" "lambda_execution_role" {
  name        = "${var.project_name}_lambda_role"
  description = "IAM execution role for ${local.lambda_function_name}"
  assume_role_policy = jsonencode(
    {
      Version = "2012-10-17",
      Statement = [
        {
          Action = "sts:AssumeRole",
          Principal = {
            Service = [
              "lambda.amazonaws.com"
            ]
          },
          Effect = "Allow",
          Sid    = "LambdaAssumeRole",
        }
      ]
    }
  )
}

resource "aws_iam_policy" "lambda_permissions" {
  name        = "${var.project_name}_lambda_permissions"
  path        = "/"
  description = "IAM policy for ${local.lambda_function_name}"

  policy = jsonencode(
    {
      Version = "2012-10-17",
      Statement = [
        {
          Action = [
            "logs:DeleteLogGroup",
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:DescribeLogGroups",
            "logs:PutRetentionPolicy",
          ],
          Resource = "arn:aws:logs:*:*:log-group:*"
          Effect   = "Allow"
          Sid      = "CloudWatchLogs",
          }, {
          Action = [
            "logs:PutLogEvents",
          ],
          Resource = "${aws_cloudwatch_log_group.lambda_logs.arn}:*",
          Effect   = "Allow",
          Sid      = "CloudWatchLogsFromThisLambda",
        },
        {
          Action = [
            "ec2:DescribeRegions",
          ],
          Resource = "*"
          Effect   = "Allow"
          Sid      = "Ec2DescribeRegions",
        }
      ]
    }
  )
}

resource "aws_iam_role_policy_attachment" "lambda_permissions" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.lambda_permissions.arn
}

resource "local_file" "env_sig" {
  content         = local.lambda_function_env_hash
  filename        = "${local.lambda_src_dir}/.env_sig.txt"
  file_permission = "0666"
}

data "archive_file" "source_zip" {
  depends_on  = [local_file.env_sig]
  type        = "zip"
  excludes    = []
  source_dir  = local.lambda_src_dir
  output_path = var.lambda_zip_file
}

resource "aws_lambda_function" "lambda_deploy" {
  description      = "Set Cloudwatch Logs Retention Period"
  filename         = var.lambda_zip_file
  function_name    = local.lambda_function_name
  role             = aws_iam_role.lambda_execution_role.arn
  handler          = "${replace(basename(var.lambda_src_filename), "/\\.py$/", "")}.lambda_handler"
  timeout          = var.lambda_timeout
  publish          = "true"
  memory_size      = var.lambda_memory_size
  architectures    = var.lambda_architectures
  source_code_hash = data.archive_file.source_zip.output_base64sha256
  runtime          = var.lambda_runtime
  environment {
    variables = local.lambda_function_environment
  }
  depends_on = [
    data.archive_file.source_zip,
    aws_cloudwatch_log_group.lambda_logs,
    aws_iam_role_policy_attachment.lambda_permissions
  ]
}

output "lambda_function_arn" {
  value = aws_lambda_function.lambda_deploy.arn
}
