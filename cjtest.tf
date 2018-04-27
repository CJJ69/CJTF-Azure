terraform {
  backend "azurerm" {
    resource_group_name = "#{Az-BlobStoreResGroup}"

    storage_account_name = "#{Az-StorageAcctName}"

    container_name = "#{Az-ContainerName}"

    key = "oct.terraform.tfstate"

    access_key = "#{Az-BlobStoreKey}"
  }
}

variable "name_prefix" {
  default = "#{NamePrefix}"
}

variable "vm_name" {
  default = "#{NamePrefix}#{VMName}"
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
  name     = "${var.name_prefix}#{ResourceGroupName}"
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

resource "azurerm_virtual_network" "vnet" {
  name                = "${var.name_prefix}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = "${azurerm_resource_group.rg.location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"

  tags {
    environment = "#{Octopus.Environment.Name}"
  }
}

resource "azurerm_subnet" "subnet" {
  name                 = "${var.name_prefix}-subnet"
  resource_group_name  = "${azurerm_resource_group.rg.name}"
  virtual_network_name = "${azurerm_virtual_network.vnet.name}"
  address_prefix       = "10.0.2.0/24"
}

resource "azurerm_public_ip" "publicip" {
  name                         = "${var.name_prefix}-publicip"
  location                     = "${azurerm_resource_group.rg.location}"
  resource_group_name          = "${azurerm_resource_group.rg.name}"
  public_ip_address_allocation = "dynamic"

  tags {
    environment = "#{Octopus.Environment.Name}"
  }
}

output "ip" {
  value = "${azurerm_public_ip.publicip.fqdn}"
}
