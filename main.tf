###############################################################################
# M1 — Pluggable model entry point
#
# Consumers call API Management with their own subscription key. API Management
# authenticates OUTWARD to the model using its managed identity — so no model
# key is ever issued, stored, or sent by the caller. That keyless hop is the
# whole point of this milestone.
###############################################################################

resource "azurerm_resource_group" "this" {
  name     = "${var.name_prefix}-rg"
  location = var.location
}

# --- Model backend: Azure OpenAI ----------------------------------------------

resource "azurerm_cognitive_account" "openai" {
  name                = "${var.name_prefix}-openai"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  kind                = "OpenAI"
  sku_name            = "S0"

  # A custom subdomain is REQUIRED for Microsoft Entra (token) auth to work.
  custom_subdomain_name = "${var.name_prefix}-openai"

  # Enforce Entra-only auth — disables API keys entirely. This is the security
  # statement of the project. Flip to `true` only if you need to test the
  # backend directly with a key during development.
  local_auth_enabled = false
}

resource "azurerm_cognitive_deployment" "model" {
  name                 = var.model_name
  cognitive_account_id = azurerm_cognitive_account.openai.id

  model {
    format  = "OpenAI"
    name    = var.model_name
    version = var.model_version
  }

  sku {
    name     = "GlobalStandard"
    capacity = var.model_capacity
  }
}

# --- API Management gateway ----------------------------------------------------

resource "azurerm_api_management" "this" {
  name                = "${var.name_prefix}-apim"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  publisher_name      = var.publisher_name
  publisher_email     = var.publisher_email
  sku_name            = var.apim_sku_name

  # System-assigned identity — this is the identity that authenticates to the model.
  identity {
    type = "SystemAssigned"
  }
}

# Grant the gateway's identity least-privilege access to the model.
# "Cognitive Services OpenAI User" allows inference calls, nothing more.
resource "azurerm_role_assignment" "apim_to_openai" {
  scope                = azurerm_cognitive_account.openai.id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id         = azurerm_api_management.this.identity[0].principal_id
}

# --- Backend, API, operation, policy ------------------------------------------

resource "azurerm_api_management_backend" "openai" {
  name                = "openai-backend"
  resource_group_name = azurerm_resource_group.this.name
  api_management_name = azurerm_api_management.this.name
  protocol            = "http"
  # The /openai base path on the model endpoint.
  url = "${azurerm_cognitive_account.openai.endpoint}openai"
}

resource "azurerm_api_management_api" "ai" {
  name                  = "ai-gateway"
  resource_group_name   = azurerm_resource_group.this.name
  api_management_name   = azurerm_api_management.this.name
  revision              = "1"
  display_name          = "AI Gateway"
  path                  = "ai"
  protocols             = ["https"]
  subscription_required = true # consumers must present a key — the per-team story starts here
}

# One operation for M1: chat completions. (You can later import the full Azure
# OpenAI OpenAPI spec for complete fidelity; one operation keeps M1 readable.)
# Callers pass ?api-version=... as a query string, per standard Azure OpenAI usage.
resource "azurerm_api_management_api_operation" "chat" {
  operation_id        = "chat-completions"
  api_name            = azurerm_api_management_api.ai.name
  api_management_name = azurerm_api_management.this.name
  resource_group_name = azurerm_resource_group.this.name
  display_name        = "Chat Completions"
  method              = "POST"
  url_template        = "/deployments/{deployment-id}/chat/completions"

  template_parameter {
    name     = "deployment-id"
    required = true
    type     = "string"
  }
}

# The heart of M1: route to the model and authenticate outward with the
# managed identity. The policy XML lives in ./policies/inbound-auth.xml.
resource "azurerm_api_management_api_policy" "ai" {
  api_name            = azurerm_api_management_api.ai.name
  api_management_name = azurerm_api_management.this.name
  resource_group_name = azurerm_resource_group.this.name

  xml_content = templatefile("${path.module}/policies/inbound-auth.xml", {
    backend_id = azurerm_api_management_backend.openai.name
  })
}

# A single demo subscription so you have a usable key to test with.
# M2 replaces this with per-team products + subscriptions.
resource "azurerm_api_management_subscription" "demo" {
  resource_group_name = azurerm_resource_group.this.name
  api_management_name = azurerm_api_management.this.name
  display_name        = "demo-consumer"
  # Strip the ;rev=N suffix — APIM only validates subscription keys for
  # scope paths without a revision, even when rev=1 is the current revision.
  api_id              = replace(azurerm_api_management_api.ai.id, ";rev=${azurerm_api_management_api.ai.revision}", "")
  state               = "active"
}
