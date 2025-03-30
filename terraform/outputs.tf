output "public_ip" {
  description = "The public IP address of the virtual machine"
  value       = azurerm_public_ip.vm.ip_address
}

output "private_ip" {
  description = "The private IP address of the virtual machine"
  value       = azurerm_network_interface.vm.ip_configuration[0].private_ip_address
}

output "internal_dns_name" {
  description = "The internal DNS name of the virtual machine"
  value       = azurerm_network_interface.vm.internal_dns_name_label
}

output "external_dns_name" {
  description = "The public DNS name of the virtual machine"
  value       = "${azurerm_public_ip.vm.domain_name_label}.${var.resource_group_location}.cloudapp.azure.com"
}
