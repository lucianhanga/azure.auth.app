variable "resource_group_name" {
  description = "The name of the resource group"
  type        = string
}

variable "resource_group_location" {
  description = "The location of the resource group"
  type        = string
}

# variable "project_name" {
#   description = "The name of the project"
#   type        = string
# }

# variable "subfix" {
#   description = "The subfix for the resources"
#   type        = string
# }

variable "client_id" {
  description = "The Client ID for the Azure Service Principal"
  type        = string
}

variable "client_secret" {
  description = "The Client Secret for the Azure Service Principal"
  type        = string
  sensitive   = true
}

variable "tenant_id" {
  description = "The Tenant ID for the Azure Service Principal"
  type        = string
}

variable "subscription_id" {
  description = "The Subscription ID for the Azure account"
  type        = string
}