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

variable "vm_count" {
  default = "2"
}

variable "datadisk_size_gb" {
  default = "10"
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

# Public IP
resource "azurerm_public_ip" "publicip" {
  name                         = "${var.name_prefix}-publicip"
  location                     = "${azurerm_resource_group.rg.location}"
  resource_group_name          = "${azurerm_resource_group.rg.name}"
  public_ip_address_allocation = "dynamic"

  tags {
    environment = "#{Octopus.Environment.Name}"
  }
}

# Load Balancer
resource "azurerm_lb" "loadbalancer" {
  name                = "${var.name_prefix}-loadbalancer"
  location            = "${azurerm_resource_group.rg.location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"

  frontend_ip_configuration {
    name                 = "publicIPAddress"
    public_ip_address_id = "${azurerm_public_ip.publicip.id}"
  }

  tags {
    environment = "#{Octopus.Environment.Name}"
  }
}

resource "azurerm_lb_backend_address_pool" "backendaddresspool" {
  name                = "${var.name_prefix}-BackEndAddressPool"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  loadbalancer_id     = "${azurerm_lb.loadbalancer.id}"
}

# Network Security Group
resource "azurerm_network_security_group" "publicipnsg" {
  name                = "${var.name_prefix}-nsg"
  location            = "${azurerm_resource_group.rg.location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"

  security_rule {
    name                       = "OctopusTentacle"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "10933"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags {
    environment = "#{Octopus.Environment.Name}"
  }
}

# Availability Set
resource "azurerm_availability_set" "avset" {
  name                         = "avset"
  location                     = "${azurerm_resource_group.rg.location}"
  resource_group_name          = "${azurerm_resource_group.rg.name}"
  platform_fault_domain_count  = 2
  platform_update_domain_count = 2
  managed                      = true
}

# Network Interface for VMs
resource "azurerm_network_interface" "nic" {
  count    = "${var.vm_count}"
  name     = "${var.vm_name}${count.index}-nic"
  location = "${azurerm_resource_group.rg.location}"

  resource_group_name = "${azurerm_resource_group.rg.name}"

  ip_configuration {
    name                                    = "${var.vm_name}-ipconfig"
    subnet_id                               = "${azurerm_subnet.subnet.id}"
    private_ip_address_allocation           = "dynamic"
    load_balancer_backend_address_pools_ids = ["${azurerm_lb_backend_address_pool.backendaddresspool.id}"]

    #   public_ip_address_id = "${azurerm_public_ip.publicip.id}"
  }

  tags {
    environment = "#{Octopus.Environment.Name}"
  }
}

resource "azurerm_managed_disk" "disk" {
  count                = "${var.vm_count}"
  name                 = "${var.vm_name}${count.index}-datadisk"
  location             = "${azurerm_resource_group.rg.location}"
  resource_group_name  = "${azurerm_resource_group.rg.name}"
  storage_account_type = "Standard_LRS"                          #"Premium_LRS"
  create_option        = "Empty"
  disk_size_gb         = "${var.datadisk_size_gb}"
}

# Virtual Machines
resource "azurerm_virtual_machine" "vm" {
  count                 = "${var.vm_count}"
  name                  = "${var.vm_name}${count.index}"
  location              = "${azurerm_resource_group.rg.location}"
  availability_set_id   = "${azurerm_availability_set.avset.id}"
  resource_group_name   = "${azurerm_resource_group.rg.name}"
  network_interface_ids = ["${element(azurerm_network_interface.nic.*.id, count.index)}"]
  vm_size               = "Standard_D1_v2"

  # Uncomment this line to delete the OS disk automatically when deleting the VM
  # delete_os_disk_on_termination = true


  # Uncomment this line to delete the data disks automatically when deleting the VM
  # delete_data_disks_on_termination = true

  storage_os_disk {
    name              = "${var.vm_name}${count.index}-osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"                        #"Premium_LRS"
  }
  storage_data_disk {
    name            = "${element(azurerm_managed_disk.disk.*.name, count.index)}"
    managed_disk_id = "${element(azurerm_managed_disk.disk.*.id, count.index)}"
    create_option   = "Attach"
    lun             = 1
    disk_size_gb    = "${element(azurerm_managed_disk.disk.*.disk_size_gb, count.index)}"
  }
  storage_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }
  os_profile {
    computer_name  = "${var.vm_name}${count.index}"
    admin_username = "${var.admin_username}"
    admin_password = "${var.admin_password}"
  }
  os_profile_windows_config {
    provision_vm_agent        = true
    enable_automatic_upgrades = false

    additional_unattend_config {
      pass         = "oobeSystem"
      component    = "Microsoft-Windows-Shell-Setup"
      setting_name = "AutoLogon"
      content      = "<AutoLogon><Password><Value>${var.admin_password}</Value></Password><Enabled>true</Enabled><LogonCount>1</LogonCount><Username>${var.admin_username}</Username></AutoLogon>"
    }
  }
}

# diagnostics storage account - Standard Locally Redundant Storage (LRS)
resource "azurerm_storage_account" "storageaccount" {
  name                     = "${lower(var.name_prefix)}diag${random_id.randomId.hex}"
  resource_group_name      = "${azurerm_resource_group.rg.name}"
  location                 = "${azurerm_resource_group.rg.location}"
  account_replication_type = "LRS"
  account_tier             = "Standard"

  tags {
    environment = "#{Octopus.Environment.Name}"
  }
}
