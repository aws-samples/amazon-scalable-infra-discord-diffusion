output "discord_interactions_endpoint_url" {
  value = module.api_gw_lambda.discord_interactions_endpoint_url
}

output "project_id" {
  value = local.unique_project
}

output "ecr_registry_url" {
  value = module.ecs_cluster.ecr_registry_url
}