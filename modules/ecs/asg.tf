# The Primary Autoscaling Group
data "aws_default_tags" "current" {}
resource "aws_autoscaling_group" "asg" {
  name                      = "asg-${var.project_id}"
  max_size                  = 2
  min_size                  = 0
  desired_capacity          = 0
  health_check_grace_period = 0
  health_check_type         = "EC2"
  default_cooldown          = 600
  launch_template {
    id      = aws_launch_template.discord_diffusion.id
    version = "$Latest"
  }
  dynamic "tag" {
    for_each = data.aws_default_tags.current.tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  vpc_zone_identifier = toset(data.aws_subnets.public.ids)
}