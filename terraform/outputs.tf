output "proxy_vm_public_ip" {
  description = "The public IP address of the proxy VM"
  value       = azurerm_public_ip.proxy-vm.ip_address
}

output "proxy_vm_private_ip" {
  description = "The private IP address of the proxy VM"
  value       = azurerm_network_interface.proxy-vm.ip_configuration[0].private_ip_address
}

output "proxy_vm_internal_dns_name" {
  description = "The internal DNS name of the proxy VM"
  value       = azurerm_network_interface.proxy-vm.internal_dns_name_label
}

output "proxy_vm_external_dns_name" {
  description = "The public DNS name of the proxy VM"
  value       = "${azurerm_public_ip.proxy-vm.domain_name_label}.${var.resource_group_location}.cloudapp.azure.com"
}

output "proxy_vm_admin_username" {
  description = "The admin username of the proxy VM"
  value       = azurerm_windows_virtual_machine.proxy-vm.admin_username
}

output "proxy_vm_computer_name" {
  description = "The computer name of the proxy VM"
  value       = azurerm_windows_virtual_machine.proxy-vm.computer_name
}

output "foo_vm_public_ip" {
  description = "The public IP address of the foo VM"
  value       = azurerm_public_ip.vm.ip_address
}

output "foo_vm_private_ip" {
  description = "The private IP address of the foo VM"
  value       = azurerm_network_interface.vm.ip_configuration[0].private_ip_address
}

output "foo_vm_internal_dns_name" {
  description = "The internal DNS name of the foo VM"
  value       = azurerm_network_interface.vm.internal_dns_name_label
}

output "foo_vm_external_dns_name" {
  description = "The public DNS name of the foo VM"
  value       = "${azurerm_public_ip.vm.domain_name_label}.${var.resource_group_location}.cloudapp.azure.com"
}

output "foo_vm_admin_username" {
  description = "The admin username of the foo VM"
  value       = azurerm_linux_virtual_machine.vm.admin_username
}

output "foo_vm_computer_name" {
  description = "The computer name of the foo VM"
  value       = azurerm_linux_virtual_machine.vm.computer_name
}

output "foo_vm_os_disk_name" {
  description = "The OS disk name of the foo VM"
  value       = azurerm_linux_virtual_machine.vm.os_disk[0].name
}

output "foo_vm_ssh_key_path" {
  description = "The path to the SSH public key used for the foo VM"
  value       = "./foo-vm-ssh-key.pub"
}

