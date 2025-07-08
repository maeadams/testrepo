output "windows_vm_ids" {
  description = "Map of Windows VM names to their IDs"
  value = {
    for k, v in azurerm_windows_virtual_machine.win_vm : k => v.id
  }
}

output "windows_vm_private_ips" {
  description = "Map of Windows VM names to their private IP addresses"
  value = {
    for k, v in azurerm_network_interface.win_nic : k => v.private_ip_address
  }
}

output "linux_vm_ids" {
  description = "Map of Linux VM names to their IDs"
  value = {
    for k, v in azurerm_linux_virtual_machine.linux_vm : k => v.id
  }
}

output "linux_vm_private_ips" {
  description = "Map of Linux VM names to their private IP addresses"
  value = {
    for k, v in azurerm_network_interface.linux_nic : k => v.private_ip_address
  }
}

output "network_interface_ids" {
  description = "Map of network interface names to their IDs."
  value = merge(
    { for k, v in azurerm_network_interface.win_nic : k => v.id },
    { for k, v in azurerm_network_interface.linux_nic : k => v.id }
  )
}

output "managed_disk_ids" {
  description = "Map of managed data disk names to their IDs."
  value       = { for k, v in azurerm_managed_disk.data_disk : k => v.id }
}

output "disk_encryption_set_id" {
  description = "ID of the Disk Encryption Set (passed from security module)"
  value       = var.disk_encryption_set_id
}

output "vm_extension_ids" {
  description = "Map of generic VM extension names to their IDs."
  value       = { for k, v in azurerm_virtual_machine_extension.generic_ext : k => v.id }
}

output "ama_windows_extension_ids" {
  description = "Map of Windows Azure Monitor Agent extension names to their IDs."
  value       = { for k, v in azurerm_virtual_machine_extension.ama_windows : k => v.id }
}

output "windows_vm_network_interface_ids" {
  description = "Map of Windows VM names to their network interface IDs"
  value = {
    for k, v in azurerm_network_interface.win_nic : k => v.id
  }
}

output "linux_vm_network_interface_ids" {
  description = "Map of Linux VM names to their network interface IDs"
  value = {
    for k, v in azurerm_network_interface.linux_nic : k => v.id
  }
}

# ✅ REMOVED: DES Principal ID now handled in security module
# The DES and its access policies are centrally managed in the security module
