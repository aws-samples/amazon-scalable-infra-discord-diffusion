# Alarms for scaling, and Lambda for pushing custom Metrics to CloudWatch

### Step Function ###
resource "aws_sfn_state_machine" "sfn_state_machine" {
  name     = var.project_id
  role_arn = aws_iam_role.step_function.arn
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
        "FunctionName": "${aws_lambda_function.lamdba_cw_metric.arn}",
        "Payload": {
          "queueUrl": "${var.sqs_queue_url}",
          "queueName": "${var.project_id}.fifo",
          "accountId": "${var.account_id}",
          "service_name": "${var.project_id}",
          "cluster_name": "${var.project_id}",
          "acceptable_latency": "90",
          "time_process_per_message": "15"
        }
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
      "Next": "Wait"
    },
    "Wait": {
      "Type": "Wait",
      "Seconds": 9,
      "Next": "Lambda Invoke (1)"
    },
    "Lambda Invoke (1)": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "OutputPath": "$.Payload",
      "Parameters": {
        "FunctionName": "${aws_lambda_function.lamdba_cw_metric.arn}",
        "Payload": {
          "queueUrl": "${var.sqs_queue_url}",
          "queueName": "${var.project_id}.fifo",
          "accountId": "${var.account_id}",
          "service_name": "${var.project_id}",
          "cluster_name": "${var.project_id}",
          "acceptable_latency": "90",
          "time_process_per_message": "15"
        }
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
      "Next": "Wait (2)"
    },
    "Wait (2)": {
      "Type": "Wait",
      "Seconds": 9,
      "Next": "Lambda Invoke (2)"
    },
    "Lambda Invoke (2)": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "OutputPath": "$.Payload",
      "Parameters": {
        "FunctionName": "${aws_lambda_function.lamdba_cw_metric.arn}",
        "Payload": {
          "queueUrl": "${var.sqs_queue_url}",
          "queueName": "${var.project_id}.fifo",
          "accountId": "${var.account_id}",
          "service_name": "${var.project_id}",
          "cluster_name": "${var.project_id}",
          "acceptable_latency": "90",
          "time_process_per_message": "15"
        }
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
      "Next": "Wait (1)"
    },
    "Wait (1)": {
      "Type": "Wait",
      "Seconds": 9,
      "Next": "Lambda Invoke (3)"
    },
    "Lambda Invoke (3)": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "OutputPath": "$.Payload",
      "Parameters": {
        "FunctionName": "${aws_lambda_function.lamdba_cw_metric.arn}",
        "Payload": {
          "queueUrl": "${var.sqs_queue_url}",
          "queueName": "${var.project_id}.fifo",
          "accountId": "${var.account_id}",
          "service_name": "${var.project_id}",
          "cluster_name": "${var.project_id}",
          "acceptable_latency": "90",
          "time_process_per_message": "15"
        }
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
      "Next": "Wait (3)"
    },
    "Wait (3)": {
      "Type": "Wait",
      "Seconds": 9,
      "Next": "Lambda Invoke (4)"
    },
    "Lambda Invoke (4)": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "OutputPath": "$.Payload",
      "Parameters": {
        "FunctionName": "${aws_lambda_function.lamdba_cw_metric.arn}",
        "Payload": {
          "queueUrl": "${var.sqs_queue_url}",
          "queueName": "${var.project_id}.fifo",
          "accountId": "${var.account_id}",
          "service_name": "${var.project_id}",
          "cluster_name": "${var.project_id}",
          "acceptable_latency": "90",
          "time_process_per_message": "15"
        }
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
      "Next": "Wait (4)"
    },
    "Wait (4)": {
      "Type": "Wait",
      "Seconds": 9,
      "Next": "Lambda Invoke (5)"
    },
    "Lambda Invoke (5)": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "OutputPath": "$.Payload",
      "Parameters": {
        "FunctionName": "${aws_lambda_function.lamdba_cw_metric.arn}",
        "Payload": {
          "queueUrl": "${var.sqs_queue_url}",
          "queueName": "${var.project_id}.fifo",
          "accountId": "${var.account_id}",
          "service_name": "${var.project_id}",
          "cluster_name": "${var.project_id}",
          "acceptable_latency": "90",
          "time_process_per_message": "15"
        }
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
      "End": true
    }
  }
}
EOF
}

resource "aws_iam_role" "step_function" {
  name = "stepFunction-${var.project_id}"
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

resource "aws_iam_policy" "step_lambda" {
  name        = "stepLambda-${var.project_id}"
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
          "${aws_lambda_function.lamdba_cw_metric.arn}"
        ]
      }
    ]
  })
}

resource "aws_iam_policy" "step_xray" {
  name        = "xray-${var.project_id}"
  path        = "/"
  description = "IAM policy for logging via xray"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords",
          "xray:GetSamplingRules",
          "xray:GetSamplingTargets"
        ],
        "Resource" : [
          "*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "step_lambda" {
  role       = aws_iam_role.step_function.name
  policy_arn = aws_iam_policy.step_lambda.arn
}

resource "aws_iam_role_policy_attachment" "step_xray" {
  role       = aws_iam_role.step_function.name
  policy_arn = aws_iam_policy.step_xray.arn
}

### EventBridge Rule to trigger Step Function ###
resource "aws_cloudwatch_event_rule" "discord_cw" {
  name        = "eventRule-${var.project_id}"
  description = "Trigger CW Lambda for custom metric every minute"

  # Cron for every minute
  schedule_expression = "rate(1 minute)"
}

resource "aws_cloudwatch_event_target" "discord_cw" {
  rule      = aws_cloudwatch_event_rule.discord_cw.name
  target_id = "TriggerStepCWMetric"
  arn       = aws_sfn_state_machine.sfn_state_machine.arn
  role_arn  = aws_iam_role.event_rule.arn
}

# Role to execute event every minute
resource "aws_iam_role" "event_rule" {
  name = "eventRule-${var.project_id}"
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

resource "aws_iam_policy" "event_rule" {
  name        = "eventRule-${var.project_id}"
  path        = "/"
  description = "IAM policy for triggering step function"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "states:StartExecution"
        ],
        "Resource" : [
          "${aws_sfn_state_machine.sfn_state_machine.arn}",
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "event_rule" {
  role       = aws_iam_role.event_rule.name
  policy_arn = aws_iam_policy.event_rule.arn
}