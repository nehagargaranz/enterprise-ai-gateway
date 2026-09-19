output "gateway_chat_completions_url" {
  description = "Full URL to call chat completions through the gateway."
  value       = "${azurerm_api_management.this.gateway_url}/ai/deployments/${azurerm_cognitive_deployment.model.name}/chat/completions?api-version=${var.openai_api_version}"
}

output "model_endpoint_is_keyless" {
  description = "Reminder: local_auth_enabled is false, so the model has no usable key — auth is Entra-only via the gateway's managed identity."
  value       = true
}
