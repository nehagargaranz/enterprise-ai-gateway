###############################################################################
# M4 — Failover
#
# The caller does not choose a region. The gateway tries the preferred backend,
# and if that hop comes back unavailable it retries the fallback once.
#
# Both backends are the same Azure OpenAI account. The preferred URL names a
# deployment that was never created, so the first hop fails on purpose — the
# same idea as Team A's low cap. The fallback URL is the live model. The
# managed identity token only ever goes to this account.
#
# The circuit breaker opens the preferred backend after one failure, so the
# next call does not sit on it.
###############################################################################

locals {
  openai_base_url = "${azurerm_cognitive_account.openai.endpoint}openai/deployments"
}

resource "azurerm_api_management_backend" "preferred" {
  name                = "openai-preferred"
  resource_group_name = azurerm_resource_group.this.name
  api_management_name = azurerm_api_management.this.name
  protocol            = "http"
  url                 = "${local.openai_base_url}/${var.preferred_deployment_name}"
  description         = "Tried first. Deployment name is not deployed, so this hop fails and the call fails over."

  circuit_breaker_rule {
    name          = "open-on-failure"
    trip_duration = "PT1M"

    failure_condition {
      interval_duration = "PT1M"
      count             = 1

      status_code_range {
        min = 404
        max = 404
      }

      status_code_range {
        min = 429
        max = 429
      }

      status_code_range {
        min = 500
        max = 599
      }
    }
  }
}

resource "azurerm_api_management_backend" "fallback" {
  name                = "openai-fallback"
  resource_group_name = azurerm_resource_group.this.name
  api_management_name = azurerm_api_management.this.name
  protocol            = "http"
  url                 = "${local.openai_base_url}/${var.model_name}"
  description         = "The live model. Serves the call when the preferred backend fails."
}
