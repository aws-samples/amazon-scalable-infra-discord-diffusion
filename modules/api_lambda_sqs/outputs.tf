output "discord_interactions_endpoint_url" {
  value = aws_apigatewayv2_api.discord_gw.api_endpoint
}

output "sqs_queue_url" {
  value = aws_sqs_queue.default_queue.url
}
