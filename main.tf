locals {
  unique_project = "${var.project_id}-${var.unique_id}"
}

data "aws_region" "current" {}

# API Gateway, Discord Lambda handler, and SQS
module "api_gw_lambda" {
  source                 = "./modules/api_lambda_sqs"
  account_id             = data.aws_caller_identity.current.account_id
  project_id             = local.unique_project
  region                 = data.aws_region.current.name
  discord_application_id = var.discord_application_id
  discord_public_key     = var.discord_public_key
  pynacl_arn             = aws_lambda_layer_version.pynacl.arn
  requests_arn           = aws_lambda_layer_version.requests.arn
}

# A Lambda function that creates the Discord UI
module "discord_ui" {
  source                 = "./modules/discord_ui"
  account_id             = data.aws_caller_identity.current.account_id
  project_id             = local.unique_project
  region                 = data.aws_region.current.name
  discord_application_id = var.discord_application_id
  requests_arn           = aws_lambda_layer_version.requests.arn
  discord_bot_secret     = var.discord_bot_secret
}

# The ECS cluster with GPUs
module "ecs_cluster" {
  source               = "./modules/ecs"
  project_id           = local.unique_project
  account_id           = data.aws_caller_identity.current.account_id
  region               = data.aws_region.current.name
  vpc_id               = var.vpc_id
  sqs_queue_url        = module.api_gw_lambda.sqs_queue_url
  huggingface_username = var.huggingface_username
  huggingface_password = var.huggingface_password
  depends_on = [
    module.api_gw_lambda,
  ]
}

# Alarms for scaling, and Lambda for pushing custom Metrics to CloudWatch
module "metrics_scaling" {
  source          = "./modules/scaling_alarm_lambda"
  project_id      = local.unique_project
  region          = data.aws_region.current.name
  vpc_id          = var.vpc_id
  account_id      = data.aws_caller_identity.current.account_id
  sqs_queue_url   = module.api_gw_lambda.sqs_queue_url
  asg_name        = module.ecs_cluster.asg_name
  asg_arn         = module.ecs_cluster.asg_arn
  ecs_service_arn = module.ecs_cluster.ecs_service_arn
  depends_on = [
    module.ecs_cluster,
    module.api_gw_lambda
  ]
}

# Lambda layers to be used for all Lambda functions
resource "aws_lambda_layer_version" "requests" {
  filename                 = "files/requests_layer_arm64.zip"
  layer_name               = "${local.unique_project}-requests"
  compatible_runtimes      = ["python3.8"]
  compatible_architectures = ["arm64"]
}

resource "aws_lambda_layer_version" "pynacl" {
  filename                 = "files/pynacl_layer_arm64.zip"
  layer_name               = "${local.unique_project}-pynacl"
  compatible_runtimes      = ["python3.8"]
  compatible_architectures = ["arm64"]
}
