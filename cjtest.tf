terraform {
  backend "azurerm" {
    resource_group_name = "#{Az-BlobStoreResGroup}"

    storage_account_name = "#{Az-StorageAcctName}"

    container_name = "#{Az-ContainerName}"

    key = "#{Az-BlobStoreKey}"
  }
}

variable "vm_name" {
  default = "#{VMName}"
}

provider "random" {
  version = "~> 1.2"
}

provider "azurerm" {
  subscription_id = "#{Az-SubscriptionId}"
  client_id       = "#{Az-ClientId}"
  client_secret   = "#{Az-ClientSecret}"
  tenant_id       = "#{Az-TenantId}"

  version = "~> 1.3"
}

resource "azurerm_resource_group" "rg" {
  name     = "#{ResourceGroupName}"
  location = "${var.azure_location}"

  tags {
    environment = "#{Octopus.Environment.Name}"
  }
}

resource "random_id" "randomId" {
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group = "${azurerm_resource_group.rg.name}"
  }

  byte_length = 8
}
