terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      # v4 is current. If your pinned azurerm is older and the v2 API Management
      # SKU strings below aren't recognised, bump this or fall back to "Developer_1".
      version = "~> 4.0"
    }
    # azurerm's diagnostic resource cannot enable custom metrics (it calls an
    # API version that has no `metrics` field). azapi sets that one flag.
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.0"
    }
  }
}

provider "azapi" {
  subscription_id = var.subscription_id
}

provider "azurerm" {
  features {}
  # azurerm v4 wants the subscription explicitly. Use your PERSONAL subscription.
  subscription_id                 = var.subscription_id
  resource_provider_registrations = "none"
}
