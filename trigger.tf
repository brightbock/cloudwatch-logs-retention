resource "aws_cloudwatch_event_rule" "trigger" {
  name                = "cron_trigger_${aws_lambda_function.lambda_deploy.function_name}"
  description         = "Periodic trigger for ${aws_lambda_function.lambda_deploy.function_name}"
  schedule_expression = var.schedule_expression
  depends_on = [
    aws_lambda_function.lambda_deploy
  ]
}

resource "aws_cloudwatch_event_target" "trigger" {
  rule      = aws_cloudwatch_event_rule.trigger.name
  target_id = "lambda"
  arn       = aws_lambda_function.lambda_deploy.arn
}

resource "aws_lambda_permission" "trigger" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_deploy.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.trigger.arn
}
