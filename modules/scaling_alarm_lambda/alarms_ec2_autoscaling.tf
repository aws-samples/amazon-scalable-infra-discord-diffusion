# Alarms the autoscaling group up and down.
resource "aws_cloudwatch_metric_alarm" "scale_down" {
  alarm_name                = "scale-down-${var.project_id}"
  comparison_operator       = "LessThanOrEqualToThreshold"
  evaluation_periods        = "150"
  datapoints_to_alarm       = "150"
  metric_name               = "ScaleAdjustmentTaskCount"
  namespace                 = "SQS AutoScaling"
  period                    = "10"
  statistic                 = "Average"
  threshold                 = "-1"
  alarm_description         = "This metric monitors the down scaling of EC2s based on Discord requests vs running EC2."
  insufficient_data_actions = []
  alarm_actions             = [aws_autoscaling_policy.scale_down.arn, aws_appautoscaling_policy.ecs_scale_down.arn]
  dimensions = {
    SQS = "${var.project_id}.fifo"
  }
}

resource "aws_cloudwatch_metric_alarm" "scale_up" {
  alarm_name                = "scale-up-${var.project_id}"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "15"
  datapoints_to_alarm       = "15"
  metric_name               = "ScaleAdjustmentTaskCount"
  namespace                 = "SQS AutoScaling"
  period                    = "10"
  statistic                 = "Average"
  threshold                 = "1"
  alarm_description         = "This metric monitors the up scaling of EC2s based on Discord requests vs running EC2."
  insufficient_data_actions = []
  alarm_actions             = [aws_autoscaling_policy.scale_up.arn, aws_appautoscaling_policy.ecs_scale_up.arn]
  dimensions = {
    SQS = "${var.project_id}.fifo"
  }
}

### EC2 Auto-Scaling Policy ###
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "scale-up-${var.project_id}"
  enabled                = true
  autoscaling_group_name = var.asg_name
  adjustment_type        = "ChangeInCapacity"
  policy_type            = "StepScaling"
  step_adjustment {
    scaling_adjustment          = 1
    metric_interval_lower_bound = 0
  }
}

resource "aws_autoscaling_policy" "scale_down" {
  name                   = "scale-down-${var.project_id}"
  enabled                = true
  autoscaling_group_name = var.asg_name
  adjustment_type        = "ChangeInCapacity"
  policy_type            = "StepScaling"
  step_adjustment {
    scaling_adjustment          = -1
    metric_interval_upper_bound = 0
  }
}