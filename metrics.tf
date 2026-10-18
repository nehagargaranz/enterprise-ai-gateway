###############################################################################
# M3 — Usage metrics & cost attribution
#
# M2 can stop a team that overruns its cap. It cannot tell finance which team
# consumed the tokens that did go through. This file records that.
#
# Each successful call emits prompt, completion, and total tokens to
# Application Insights, labelled with the team (the product on the caller's
# key). The diagnostic below is deliberately token-only: request and response
# bodies are not stored, and the subscription key is not a header we log.
# The record is the usage, not the conversation.
###############################################################################

resource "azurerm_log_analytics_workspace" "usage" {
  name                = "${var.name_prefix}-law"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  # A POC safety rail. A handful of demo calls will not approach this.
  daily_quota_gb = 1
}

resource "azurerm_application_insights" "usage" {
  name                = "${var.name_prefix}-appi"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  workspace_id        = azurerm_log_analytics_workspace.usage.id
  application_type    = "other"
}

resource "azurerm_api_management_logger" "usage" {
  name                = "usage-logger"
  api_management_name = azurerm_api_management.this.name
  resource_group_name = azurerm_resource_group.this.name
  resource_id         = azurerm_application_insights.usage.id

  application_insights {
    connection_string = azurerm_application_insights.usage.connection_string
  }
}

# Attached to the AI API only. Sampling stays at 100%: a sampled token
# total is not something you can hand to finance.
resource "azurerm_api_management_api_diagnostic" "usage" {
  identifier               = "applicationinsights"
  resource_group_name      = azurerm_resource_group.this.name
  api_management_name      = azurerm_api_management.this.name
  api_name                 = azurerm_api_management_api.ai.name
  api_management_logger_id = azurerm_api_management_logger.usage.id

  sampling_percentage       = 100
  always_log_errors         = true
  log_client_ip             = false
  verbosity                 = "information"
  http_correlation_protocol = "W3C"

  frontend_request {
    body_bytes     = 0
    headers_to_log = ["Content-Type"]
  }

  frontend_response {
    body_bytes     = 0
    headers_to_log = ["Content-Type"]
  }

  backend_request {
    body_bytes     = 0
    headers_to_log = ["Content-Type"]
  }

  backend_response {
    body_bytes     = 0
    headers_to_log = ["Content-Type"]
  }
}

# Without this, the token policy runs and the numbers go nowhere. azurerm
# creates the diagnostic through an API version that has no metrics field.
resource "azapi_update_resource" "usage_metrics" {
  type        = "Microsoft.ApiManagement/service/apis/diagnostics@2024-05-01"
  resource_id = azurerm_api_management_api_diagnostic.usage.id

  body = {
    properties = {
      metrics = true
    }
  }
}