output "ip" {
  value = "${azurerm_public_ip.publicip.fqdn}"
}

output "DiagnosticStorage" {
  value = "${azurerm_storage_account.storageaccount.name}"
}
