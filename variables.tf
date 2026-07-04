variable "subscription_id" {
  description = "Azure subscription ID."
  type        = string
}

variable "location" {
  description = <<-EOT
    Azure region. NOTE: Azure OpenAI model availability is region-specific —
    confirm your chosen model + version exists here before applying
    (`az cognitiveservices account list-models ...` or the Foundry portal).
  EOT
  type        = string
  default     = "newzealandnorth"
}

variable "name_prefix" {
  description = "Short prefix for resource names. Keep it lowercase/alphanumeric."
  type        = string
  default     = "aigw"
}

# --- API Management ---

variable "apim_sku_name" {
  description = <<-EOT
    API Management SKU. "StandardV2_1" provisions fast and supports the AI gateway
    features. "Developer_1" also works but provisions slowly (tens of minutes).
    Confirm the v2 SKU is available in your region/azurerm version.
  EOT
  type        = string
  default     = "BasicV2_1"
}

variable "publisher_name" {
  description = "Required by API Management. Your name."
  type        = string
  default     = "Neha Garg"
}

variable "publisher_email" {
  description = "Required by API Management. Your email."
  type        = string
  default     = "nehagarg2291@gmail.com"
}

# --- Model backend (pluggable) ---
# For M1 the backend is one Azure OpenAI deployment. Keeping it in variables is
# deliberate: M2+ swaps/extends providers without touching the wiring.

variable "model_name" {
  description = "Model to deploy."
  type        = string
  default     = "gpt-4o-mini" // it is in deprecating state — Azure blocks new deployments of deprecated model versions
}

variable "model_version" {
  description = "Model version — VERIFY this is available in your region; versions change."
  type        = string
  default     = "2024-07-18"
}

variable "model_capacity" {
  description = "Deployment capacity (thousands of tokens/min). Keep low for a POC."
  type        = number
  default     = 10
}

variable "openai_api_version" {
  description = "Azure OpenAI data-plane API version used in the gateway URL output."
  type        = string
  default     = "2024-10-21"
}
