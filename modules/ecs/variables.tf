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

variable "huggingface_username" {
  description = "Username to the website hugging face. Used to download models."
  type        = string
}

variable "huggingface_password" {
  description = "Password to the website hugging face. Used to download models."
  type        = string
}