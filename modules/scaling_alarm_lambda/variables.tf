variable "project_id" {
  description = "Overall project name"
  type        = string
}

variable "account_id" {
  description = "AWS Account id"
  type        = string
}

variable "region" {
  description = "AWS region to build infrastructure"
  type        = string
}

variable "vpc_id" {
  description = "Pre-exisiting VPC ARN"
  type        = string
}

variable "sqs_queue_url" {
  description = "SQS Queue URL"
  type        = string
}

variable "asg_name" {
  description = "EC2 AutoScaler Group Name"
  type        = string
}

variable "asg_arn" {
  description = "EC2 AutoScaler ARN"
  type        = string
}

variable "ecs_service_arn" {
  description = "ECS Service ARN"
  type        = string
}