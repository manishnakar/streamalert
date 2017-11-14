// Lambda function: Threat Intel Downloader
// It retrieves IOCs and stores them in DynamoDB table
resource "aws_lambda_function" "threat_intel_downloader" {
  function_name = "${var.prefix}_streamalert_threat_intel_downloader"
  description   = "StreamAlert Threat Intel Downloader"
  runtime       = "python2.7"
  role          = "${aws_iam_role.threat_intel_downloader.arn}"
  handler       = "${var.lambda_handler}"
  memory_size   = "${var.lambda_memory}"
  timeout       = "${var.lambda_timeout}"
  s3_bucket     = "${var.lambda_s3_bucket}"
  s3_key        = "${var.lambda_s3_key}"

  environment {
    variables = {
      LOGGER_LEVEL   = "${var.lambda_log_level}"
      ENABLE_METRICS = "${var.enable_metrics}"
    }
  }

  dead_letter_config {
    target_arn = "arn:aws:sns:${var.region}:${var.account_id}:${var.monitoring_sns_topic}"
  }

  tags {
    Name = "ThreatIntel"
  }
}

// Lambda Alias: Threat Intel Downloader Production
resource "aws_lambda_alias" "threat_intel_downloader_production" {
  name             = "production"
  description      = "Production Threat Intel Dowwnloader Alias"
  function_name    = "${aws_lambda_function.threat_intel_downloader.arn}"
  function_version = "${var.current_version}"
}

// Lambda Permission: Allow Cloudwatch Scheduled Events to invoke Lambda
resource "aws_lambda_permission" "allow_cloudwatch_events_invocation" {
  statement_id  = "CloudwatchEventsInvokeAthenaRefresh"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.threat_intel_downloader.function_name}"
  principal     = "events.amazonaws.com"
  source_arn    = "${aws_cloudwatch_event_rule.invoke_threat_intel_downloader.arn}"
  qualifier     = "production"

  # explicit dependency
  depends_on = ["aws_lambda_alias.threat_intel_downloader_production"]
}

// Cloudwatch Event Rule: Invoke the threat_intel_downloader once a day
resource "aws_cloudwatch_event_rule" "invoke_threat_intel_downloader" {
  name        = "invoke_threat_intel_downloader"
  description = "Invoke the Threat Intel Downloader Lambda function once a day"

  # https://amzn.to/2u5t0hS
  schedule_expression = "${var.interval}"
}

// Cloudwatch Event Target: Point the threat intel downloader rule to the Lambda function
resource "aws_cloudwatch_event_target" "threat_intel_downloader_lambda_function" {
  rule = "${aws_cloudwatch_event_rule.invoke_threat_intel_downloader.name}"
  arn  = "${aws_lambda_function.threat_intel_downloader.arn}:production"

  # explicit dependency
  depends_on = ["aws_lambda_alias.threat_intel_downloader_production"]
}

// Log Retention Policy: lambda function
resource "aws_cloudwatch_log_group" "threat_intel_downloader" {
  name              = "/aws/lambda/${var.prefix}_streamalert_threat_intel_downloader"
  retention_in_days = 60
}

# TODO: check if `aws_cloudwatch_log_metric_filter` needed.

