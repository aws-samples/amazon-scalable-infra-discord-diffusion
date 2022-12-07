# Start From Zero method

### Lambda start from zero ###
locals {
  log_lamdba_start_from_zero = "/aws/lambda/start-from-zero-${var.project_id}"
  log_sfn_start_from_zero    = "/aws/vendedlogs/states/sfn-start-from-zero-${var.project_id}"
}

# Lambda Function for custom CloudWatch Metrics
resource "aws_lambda_function" "lamdba_start_from_zero" {
  function_name    = "start-from-zero-${var.project_id}"
  description      = "Checks if there is a message and no instances. Starts an instance if true."
  filename         = "${path.module}/files/start_from_zero.zip"
  source_code_hash = data.archive_file.lamdba_start_from_zero.output_base64sha256
  runtime          = "python3.8"
  architectures    = ["arm64"]
  role             = aws_iam_role.lamdba_start_from_zero.arn
  handler          = "start_from_zero.lambda_handler"

  environment {
    variables = {
      AUTOSCALING_GROUP = var.asg_name,
      SQS_QUEUE_URL     = var.sqs_queue_url,
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.AutoScalingReadOnlyAccess,
    aws_iam_role_policy_attachment.AmazonSQSReadOnlyAccess_zero,
    aws_iam_role_policy_attachment.asg_start_from_zero,
    aws_cloudwatch_log_group.lamdba_start_from_zero,
    data.archive_file.lamdba_start_from_zero
  ]
}

data "archive_file" "lamdba_start_from_zero" {
  type        = "zip"
  source_dir  = "${path.module}/files/start_from_zero"
  output_path = "${path.module}/files/start_from_zero.zip"
}

resource "aws_cloudwatch_log_group" "lamdba_start_from_zero" {
  name              = local.log_lamdba_start_from_zero
  retention_in_days = 14
}

resource "aws_iam_policy" "lambda_start_from_zero_lambda_logging" {
  name        = "start-from-zero-logging-${var.project_id}"
  path        = "/"
  description = "IAM policy for logging from a lambda"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : "logs:CreateLogGroup",
        "Resource" : "arn:aws:logs:${var.region}:${var.account_id}:*"
      },
      {
        "Action" : [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        "Resource" : "arn:aws:logs:${var.region}:${var.account_id}:log-group:${local.log_lamdba_start_from_zero}:*",
        "Effect" : "Allow"
      }
    ]
  })
}

resource "aws_iam_policy" "asg_start_from_zero" {
  name        = "asg-set-desired-capacity-${var.project_id}"
  path        = "/"
  description = "Describe ECS Service"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : "autoscaling:SetDesiredCapacity",
        "Resource" : "${var.asg_arn}"
      }
    ]
  })
}

resource "aws_iam_role" "lamdba_start_from_zero" {
  name = "start-from-zero-${var.project_id}"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "lambda.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "AutoScalingReadOnlyAccess" {
  name        = "AutoScalingReadOnlyAccess-${var.project_id}"
  path        = "/"
  description = "IAM policy for Reading an Autoscaling group"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : "autoscaling:Describe*",
        "Resource" : "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "AutoScalingReadOnlyAccess" {
  role       = aws_iam_role.lamdba_start_from_zero.name
  policy_arn = resource.aws_iam_policy.AutoScalingReadOnlyAccess.arn
}

resource "aws_iam_role_policy_attachment" "AmazonSQSReadOnlyAccess_zero" {
  role       = aws_iam_role.lamdba_start_from_zero.name
  policy_arn = resource.aws_iam_policy.AmazonSQSReadOnlyAccess.arn
}

resource "aws_iam_role_policy_attachment" "asg_start_from_zero" {
  role       = aws_iam_role.lamdba_start_from_zero.name
  policy_arn = aws_iam_policy.asg_start_from_zero.arn
}


### Step Function ###
resource "aws_sfn_state_machine" "zero_state_machine" {
  name     = "start-from-zero-${var.project_id}"
  role_arn = aws_iam_role.sfn_start_from_zero.arn
  type     = "EXPRESS"

  definition = <<EOF
{
  "Comment": "A description of my state machine",
  "StartAt": "Lambda Invoke",
  "States": {
    "Lambda Invoke": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "OutputPath": "$.Payload",
      "Parameters": {
        "FunctionName": "${aws_lambda_function.lamdba_start_from_zero.arn}:$LATEST"
      },
      "Retry": [
        {
          "ErrorEquals": [
            "Lambda.ServiceException",
            "Lambda.AWSLambdaException",
            "Lambda.SdkClientException"
          ],
          "IntervalSeconds": 2,
          "MaxAttempts": 6,
          "BackoffRate": 2
        }
      ],
      "Next": "Choice",
      "Comment": "Updates ASG to 1: If zero instances and 1 item in SQS queue."
    },
    "Choice": {
      "Type": "Choice",
      "Choices": [
        {
          "Variable": "$",
          "BooleanEquals": true,
          "Next": "Start from Zero"
        }
      ],
      "Default": "Exit",
      "Comment": "Either exits or continues to update ECS Service"
    },
    "Exit": {
      "Type": "Pass",
      "End": true
    },
    "Start from Zero": {
      "Type": "Pass",
      "Next": "Wait"
    },
    "Wait": {
      "Type": "Wait",
      "Seconds": 55,
      "Next": "UpdateService",
      "Comment": "Wait X time for EC2 instance to come online following Lambda and become registered to ECS cluster"
    },
    "UpdateService": {
      "Type": "Task",
      "End": true,
      "Parameters": {
        "Service": "${var.project_id}",
        "DesiredCount": 1,
        "Cluster": "${var.project_id}"
      },
      "Resource": "arn:aws:states:::aws-sdk:ecs:updateService",
      "Comment": "Update Service from 0 -> 1"
    }
  }
}
EOF

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.sfn_start_from_zero.arn}:*"
    include_execution_data = true
    level                  = "ERROR"
  }

  depends_on = [
    aws_cloudwatch_log_group.sfn_start_from_zero,
    aws_iam_role_policy_attachment.step_logging_zero,
    aws_iam_role.sfn_start_from_zero
  ]

}

resource "aws_cloudwatch_log_group" "sfn_start_from_zero" {
  name              = local.log_sfn_start_from_zero
  retention_in_days = 14
}

resource "aws_iam_role" "sfn_start_from_zero" {
  name = "startFromZero-sfn-${var.project_id}"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : "sts:AssumeRole",
        "Principal" : {
          "Service" : "states.amazonaws.com"
        },
        "Effect" : "Allow",
      }
    ]
  })
}

resource "aws_iam_policy" "step_logging_zero" {
  name        = "start-from-zero-step-logging-${var.project_id}"
  path        = "/"
  description = "IAM policy for logging with a step function"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "logs:CreateLogDelivery",
          "logs:GetLogDelivery",
          "logs:UpdateLogDelivery",
          "logs:DeleteLogDelivery",
          "logs:ListLogDeliveries",
          "logs:PutLogEvents",
          "logs:PutResourcePolicy",
          "logs:DescribeResourcePolicies",
          "logs:DescribeLogGroups"
        ],
        "Resource" : "*"
      }
    ]
  })
}

resource "aws_iam_policy" "step_lambda_zero" {
  name        = "startFromZero-sfn-lambda-${var.project_id}"
  path        = "/"
  description = "IAM policy for running lambda for step function"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "lambda:InvokeFunction"
        ],
        "Resource" : [
          "${aws_lambda_function.lamdba_start_from_zero.arn}:*"
        ]
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "lambda:InvokeFunction"
        ],
        "Resource" : [
          "${aws_lambda_function.lamdba_start_from_zero.arn}"
        ]
      }
    ]
  })
}

resource "aws_iam_policy" "step_update_service_zero" {
  name        = "startFromZero-updateService-${var.project_id}"
  path        = "/"
  description = "IAM policy for updating an AutoScaling Group's Desired number."

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : "ecs:UpdateService",
        "Resource" : "${var.ecs_service_arn}"
      }
    ]
  })
}

resource "aws_iam_policy" "invoke_lambda_zero" {
  name        = "startFromZero-invokeLambda-${var.project_id}"
  path        = "/"
  description = "IAM policy for triggering a specific Lamdba function."

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "lambda:InvokeFunction"
        ],
        "Resource" : [
          "${aws_lambda_function.lamdba_start_from_zero.arn}"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "step_lambda_zero" {
  role       = aws_iam_role.sfn_start_from_zero.name
  policy_arn = aws_iam_policy.step_lambda_zero.arn
}

resource "aws_iam_role_policy_attachment" "step_xray_zero" {
  role       = aws_iam_role.sfn_start_from_zero.name
  policy_arn = aws_iam_policy.step_xray.arn
}

resource "aws_iam_role_policy_attachment" "step_update_service_zero" {
  role       = aws_iam_role.sfn_start_from_zero.name
  policy_arn = aws_iam_policy.step_update_service_zero.arn
}

resource "aws_iam_role_policy_attachment" "invoke_lambda_zero" {
  role       = aws_iam_role.sfn_start_from_zero.name
  policy_arn = aws_iam_policy.invoke_lambda_zero.arn
}

resource "aws_iam_role_policy_attachment" "step_logging_zero" {
  role       = aws_iam_role.sfn_start_from_zero.name
  policy_arn = aws_iam_policy.step_logging_zero.arn
}

### Create Alarm for triggering Step Function ###
resource "aws_cloudwatch_metric_alarm" "start_from_zero" {
  alarm_name                = "start-from-zero-${var.project_id}"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  datapoints_to_alarm       = "1"
  metric_name               = "ApproximateNumberOfMessages"
  namespace                 = "SQS AutoScaling"
  period                    = "10"
  statistic                 = "Average"
  threshold                 = ".2"
  alarm_description         = "This metric alarms when there is something in the queue or process in the queue."
  insufficient_data_actions = []
  alarm_actions             = []
  dimensions = {
    SQS = "${var.project_id}.fifo"
  }
}

resource "aws_cloudwatch_event_rule" "start_from_zero" {
  name        = "start-from-zero-${var.project_id}"
  description = "Run start-from-zero step function when transitioning to ALARM state"

  event_pattern = <<EOF
{
  "source": ["aws.cloudwatch"],
  "detail-type": ["CloudWatch Alarm State Change"],
  "resources": ["${aws_cloudwatch_metric_alarm.start_from_zero.arn}"],
  "detail": {
    "state": {
      "value": ["ALARM"]
    }
  }
}
EOF
}

### Event Bridge Trigger ###
resource "aws_iam_role" "rule_start_from_zero" {
  name = "startFromZero-rule-${var.project_id}"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : "sts:AssumeRole",
        "Principal" : {
          "Service" : "events.amazonaws.com"
        },
        "Effect" : "Allow",
      }
    ]
  })
}

resource "aws_iam_policy" "start_from_zero_rule" {
  name        = "startFromZero-rule-${var.project_id}"
  path        = "/"
  description = "IAM policy for triggering a specific step function from EventBridge."

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "states:StartExecution"
        ],
        "Resource" : [
          "${aws_sfn_state_machine.zero_state_machine.arn}"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "start_from_zero_rule" {
  role       = aws_iam_role.rule_start_from_zero.name
  policy_arn = aws_iam_policy.start_from_zero_rule.arn
}

resource "aws_cloudwatch_event_target" "start_from_zero_sfn" {
  rule      = aws_cloudwatch_event_rule.start_from_zero.name
  role_arn  = aws_iam_role.rule_start_from_zero.arn
  target_id = "start-from-zero-${var.project_id}"
  arn       = aws_sfn_state_machine.zero_state_machine.arn
}