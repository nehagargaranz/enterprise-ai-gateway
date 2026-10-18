output "gateway_chat_completions_url" {
  description = "Full URL to call chat completions through the gateway."
  value       = "${azurerm_api_management.this.gateway_url}/ai/deployments/${azurerm_cognitive_deployment.model.name}/chat/completions?api-version=${var.openai_api_version}"
}

output "model_endpoint_is_keyless" {
  description = "Reminder: local_auth_enabled is false, so the model has no usable key — auth is Entra-only via the gateway's managed identity."
  value       = true
}

output "team_subscription_keys" {
  description = "Per-team subscription keys. Send as the 'Ocp-Apim-Subscription-Key' header."
  value       = { for k, s in azurerm_api_management_subscription.team : k => s.primary_key }
  sensitive   = true
}

output "resource_group_name" {
  description = "Resource group holding the gateway and the usage workspace."
  value       = azurerm_resource_group.this.name
}

output "application_insights_name" {
  description = "Application Insights resource that holds per-team token metrics."
  value       = azurerm_application_insights.usage.name
}