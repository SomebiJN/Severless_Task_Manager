# Output value definitions

output "api_gateway_url" {
  value = "https://${aws_api_gateway_rest_api.task_api.id}.execute-api.us-west-2.amazonaws.com/${aws_api_gateway_stage.prod.stage_name}"
}

