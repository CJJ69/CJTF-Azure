variable "azure_location" {
  description = "The Azure location to create things in."
  default     = "uksouth"
}

variable "octopus_server_url" {
  description = "Octopus Server Public Url"
  default     = "#{OctopusServerUrl}"
}

variable "octopus_api_key" {
  description = "Octopus Api Key"
  default     = "#{OctopusApiKey}"
}

variable admin_username {
  default = "#{AdminUsername}"
}

variable admin_password {
  default = "#{AdminPassword}"
}

variable "dsc_endpoint" {
  default = "[azure_automation_url]"
}
