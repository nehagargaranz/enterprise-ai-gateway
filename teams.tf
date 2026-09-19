###############################################################################
# M2 — Per-team access & token rate limiting
#
# Each "team" is an API Management PRODUCT with its own subscription key and its
# own token-per-minute cap. One team hammering the model can't starve another,
# and each cap is tuned independently: add, remove, or re-tune a team by editing
# the `teams` map below — nothing else changes.
###############################################################################

variable "teams" {
  description = <<-EOT
    Consumer teams. Each gets its own product, subscription key, and token cap.
    Keep one cap low so the rate-limit demo is easy (and cheap) to trip.
  EOT
  type = map(object({
    display_name      = string
    tokens_per_minute = number
  }))
  default = {
    "team-a" = { display_name = "Team A (low cap - demo)", tokens_per_minute = 2000 }
    "team-b" = { display_name = "Team B (normal cap)", tokens_per_minute = 5000 }
  }
}

# One product per team.
resource "azurerm_api_management_product" "team" {
  for_each = var.teams

  product_id            = each.key
  display_name          = each.value.display_name
  resource_group_name   = azurerm_resource_group.this.name
  api_management_name   = azurerm_api_management.this.name
  subscription_required = true
  approval_required     = false
  published             = true
}

# Give each team's product access to the AI Gateway API from M1.
resource "azurerm_api_management_product_api" "team" {
  for_each = var.teams

  product_id          = azurerm_api_management_product.team[each.key].product_id
  api_name            = azurerm_api_management_api.ai.name
  api_management_name = azurerm_api_management.this.name
  resource_group_name = azurerm_resource_group.this.name
}

# Per-team token cap. Keyed on the subscription ID, so each team has its own
# bucket — one team's 429 doesn't touch another.
resource "azurerm_api_management_product_policy" "team" {
  for_each = var.teams

  product_id          = azurerm_api_management_product.team[each.key].product_id
  api_management_name = azurerm_api_management.this.name
  resource_group_name = azurerm_resource_group.this.name

  xml_content = templatefile("${path.module}/policies/token-limit.xml", {
    tokens_per_minute = each.value.tokens_per_minute
  })
}

# One subscription (key) per team.
resource "azurerm_api_management_subscription" "team" {
  for_each = var.teams

  resource_group_name = azurerm_resource_group.this.name
  api_management_name = azurerm_api_management.this.name
  display_name        = "${each.key}-consumer"
  product_id          = azurerm_api_management_product.team[each.key].id
  state               = "active"
}

output "team_subscription_keys" {
  description = "Per-team subscription keys. Send as the 'Ocp-Apim-Subscription-Key' header."
  value       = { for k, s in azurerm_api_management_subscription.team : k => s.primary_key }
  sensitive   = true
}
