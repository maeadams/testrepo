terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }
}

locals {
  # Process Windows VM data disks
  windows_data_disks = length(var.windows_vms) > 0 ? {
    for pair in flatten([
      for vm_key, vm_config in var.windows_vms : [
        for disk_idx, disk_config in lookup(vm_config, "data_disks", []) : {
          key = "${vm_key}-${disk_config.name}"
          value = {
            vm_key               = vm_key
            vm_type              = "windows"
            name                 = disk_config.name
            lun                  = disk_config.lun
            caching              = disk_config.caching
            storage_account_type = disk_config.storage_account_type
            disk_size_gb         = disk_config.disk_size_gb
            create_option        = disk_config.create_option
            tags                 = lookup(vm_config, "tags", null)
          }
        }
      ] if lookup(vm_config, "data_disks", null) != null
    ]) : pair.key => pair.value
  } : {}

  # Process Linux VM data disks
  linux_data_disks = length(var.linux_vms) > 0 ? {
    for pair in flatten([
      for vm_key, vm_config in var.linux_vms : [
        for disk_idx, disk_config in lookup(vm_config, "data_disks", []) : {
          key = "${vm_key}-${disk_config.name}"
          value = {
            vm_key               = vm_key
            vm_type              = "linux"
            name                 = disk_config.name
            lun                  = disk_config.lun
            caching              = disk_config.caching
            storage_account_type = disk_config.storage_account_type
            disk_size_gb         = disk_config.disk_size_gb
            create_option        = disk_config.create_option
            tags                 = lookup(vm_config, "tags", null)
          }
        }
      ] if lookup(vm_config, "data_disks", null) != null
    ]) : pair.key => pair.value
  } : {}

  # Merge the Windows and Linux data disks
  all_data_disks = merge(local.windows_data_disks, local.linux_data_disks)
}

data "azurerm_client_config" "current" {}

# ✅ REMOVED: Use random_suffix passed from main.tf instead of local random_string
# This ensures consistent naming across all resources

# ✅ REMOVED: DES creation moved to security module to avoid conflicts
# Each compute module will use the shared DES created in the security module
# This prevents naming conflicts and duplicate access policies

# ✅ REMOVED: Access policy creation moved to security module
# This prevents duplicate access policies for the same DES identity

# ✅ NETWORK INTERFACES for Windows VMs
resource "azurerm_network_interface" "win_nic" {
  for_each = var.windows_vms

  name                = "${each.value.name_prefix}-${var.random_suffix}-nic"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = lookup(each.value, "tags", null)

  ip_configuration {
    name                          = "${each.value.name_prefix}-ipconfig"
    subnet_id                     = var.subnet_ids[each.value.subnet_name]
    private_ip_address_allocation = "Dynamic"
  }
}

# ✅ CRITICAL: Key Vault dependency signal - prevents Key Vault early deletion
resource "null_resource" "key_vault_dependency_signal" {
  triggers = {
    key_vault_id           = var.key_vault_id
    disk_encryption_set_id = var.disk_encryption_set_id
    resource_group         = var.resource_group_name
    timestamp              = timestamp()
  }

  # This resource must exist while VMs are using Key Vault-dependent resources
  lifecycle {
    create_before_destroy = false
  }
}

# ✅ ENHANCED: Windows VMs with better lifecycle management
resource "azurerm_windows_virtual_machine" "win_vm" {
  for_each = var.windows_vms

  name                = "${each.value.name_prefix}-${var.random_suffix}"
  computer_name       = lookup(each.value, "computer_name", substr(each.value.name_prefix, 0, 15))
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = each.value.size
  admin_username      = each.value.admin_username
  admin_password      = each.value.admin_password

  network_interface_ids = [
    azurerm_network_interface.win_nic[each.key].id
  ]
  tags = lookup(each.value, "tags", null)

  source_image_reference {
    publisher = each.value.source_image_reference.publisher
    offer     = each.value.source_image_reference.offer
    sku       = each.value.source_image_reference.sku
    version   = each.value.source_image_reference.version
  }

  os_disk {
    caching              = each.value.os_disk.caching
    storage_account_type = each.value.os_disk.storage_account_type
    disk_encryption_set_id = var.disk_encryption_set_id
  }

  # ✅ CRITICAL: Fixed ignore_changes (removed virtual_machine_id warning)
  lifecycle {
    ignore_changes = [
      # Ignore Azure-managed attributes that change on their own
      patch_mode,
      secure_boot_enabled,
      vtpm_enabled,
      bypass_platform_safety_checks_on_user_schedule_enabled,
      hotpatching_enabled,
      provision_vm_agent,
      
      # ✅ REMOVED: virtual_machine_id (was causing warning)
      # virtual_machine_id,
      
      # Ignore case differences in resource IDs
      os_disk[0].disk_encryption_set_id,
      
      # Ignore disk size changes (Azure may adjust these)
      os_disk[0].disk_size_gb,
      os_disk[0].name,
      
      # Ignore other Azure-managed fields
      termination_notification
    ]
  }

  depends_on = [
    null_resource.des_usage_signal,
    null_resource.key_vault_dependency_signal
  ]
}

# ✅ NETWORK INTERFACES for Linux VMs
resource "azurerm_network_interface" "linux_nic" {
  for_each = var.linux_vms

  name                = "${each.value.name_prefix}-${var.random_suffix}-nic"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = lookup(each.value, "tags", null)

  ip_configuration {
    name                          = "${each.value.name_prefix}-ipconfig"
    subnet_id                     = var.subnet_ids[each.value.subnet_name]
    private_ip_address_allocation = "Dynamic"
  }
}

# ✅ LINUX VIRTUAL MACHINES - with proper DES dependency
resource "azurerm_linux_virtual_machine" "linux_vm" {
  for_each = var.linux_vms

  name                = "${each.value.name_prefix}-${var.random_suffix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = each.value.size
  admin_username      = each.value.admin_username

  network_interface_ids = [
    azurerm_network_interface.linux_nic[each.key].id
  ]
  tags = lookup(each.value, "tags", null)

  admin_ssh_key {
    username   = each.value.admin_ssh_key.username
    public_key = each.value.admin_ssh_key.public_key
  }

  source_image_reference {
    publisher = each.value.source_image_reference.publisher
    offer     = each.value.source_image_reference.offer
    sku       = each.value.source_image_reference.sku
    version   = each.value.source_image_reference.version
  }

  os_disk {
    caching              = each.value.os_disk.caching
    storage_account_type = each.value.os_disk.storage_account_type
    # ✅ CONDITIONAL: Use shared DES ID passed from security module
    disk_encryption_set_id = var.disk_encryption_set_id
  }

  depends_on = [null_resource.des_usage_signal]
}

# ✅ MANAGED DISKS with encryption
resource "azurerm_managed_disk" "data_disk" {
  for_each = local.all_data_disks

  name                 = each.value.name
  location             = var.location
  resource_group_name  = var.resource_group_name
  storage_account_type = each.value.storage_account_type
  create_option        = each.value.create_option
  disk_size_gb         = each.value.disk_size_gb
  tags                 = each.value.tags

  # ✅ ENABLE: Disk encryption for data disks
  disk_encryption_set_id = var.disk_encryption_set_id

  depends_on = [null_resource.des_usage_signal]
}

# Data Disk Attachments for Windows VMs
resource "azurerm_virtual_machine_data_disk_attachment" "win_vm_data_disk" {
  for_each = { for k, v in local.all_data_disks : k => v if v.vm_type == "windows" }

  managed_disk_id    = azurerm_managed_disk.data_disk[each.key].id
  virtual_machine_id = azurerm_windows_virtual_machine.win_vm[each.value.vm_key].id
  lun                = each.value.lun
  caching            = each.value.caching
  create_option      = "Attach"
}

# Data Disk Attachments for Linux VMs
resource "azurerm_virtual_machine_data_disk_attachment" "linux_vm_data_disk" {
  for_each = { for k, v in local.all_data_disks : k => v if v.vm_type == "linux" }

  managed_disk_id    = azurerm_managed_disk.data_disk[each.key].id
  virtual_machine_id = azurerm_linux_virtual_machine.linux_vm[each.value.vm_key].id
  lun                = each.value.lun
  caching            = each.value.caching
  create_option      = "Attach"
}

# ✅ CRITICAL: DES dependency signal - tells security module this compute module is using DES
resource "null_resource" "des_usage_signal" {
  # Always create this resource - use triggers to handle null values
  triggers = {
    des_id         = var.disk_encryption_set_id != null ? var.disk_encryption_set_id : "none"
    resource_group = var.resource_group_name
    timestamp      = timestamp()
  }

  # This resource exists while VMs are using DES
  # When this is destroyed, it signals that DES can be safely deleted
  lifecycle {
    create_before_destroy = false
  }
}

# ✅ ENHANCED: Azure Monitor Agent with better lifecycle management
resource "azurerm_virtual_machine_extension" "ama_windows" {
  for_each = {
    for k, v in var.windows_vms : k => v if lookup(v, "enable_azure_monitor_agent", true)
  }

  name                       = "${each.value.name_prefix}-AMA"
  virtual_machine_id         = azurerm_windows_virtual_machine.win_vm[each.key].id
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorWindowsAgent"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true

  settings = jsonencode({
    "workspaceId" = var.log_analytics_workspace_id
  })

  protected_settings = jsonencode({
    "workspaceKey" = var.log_analytics_workspace_key
  })

  # ✅ CRITICAL: Prevent unnecessary recreation
  lifecycle {
    prevent_destroy = false
    create_before_destroy = false
    ignore_changes = [
      # Ignore changes that would cause recreation
      settings,
      protected_settings,
      type_handler_version,
      # Ignore Azure-managed properties
      auto_upgrade_minor_version
    ]
  }

  # ✅ AGGRESSIVE timeouts to prevent hanging
  # timeouts {
  #   create = "10m"
  #   update = "10m"
  #   delete = "5m"
  # }

  depends_on = [
    azurerm_windows_virtual_machine.win_vm,
    null_resource.ensure_vm_running_before_extensions,
    null_resource.key_vault_dependency_signal
  ]
}

# Linux Azure Monitor Agent
resource "azurerm_virtual_machine_extension" "ama_linux" {
  for_each = {
    for k, v in var.linux_vms : k => v if lookup(v, "enable_azure_monitor_agent", true)
  }

  name                       = "${each.value.name_prefix}-AMA"
  virtual_machine_id         = azurerm_linux_virtual_machine.linux_vm[each.key].id
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorLinuxAgent"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true

  settings = jsonencode({
    "workspaceId" = var.log_analytics_workspace_id
  })

  protected_settings = jsonencode({
    "workspaceKey" = var.log_analytics_workspace_key
  })

  # timeouts {
  #   create = "30m"
  #   update = "30m"
  #   delete = "30m"
  # }

  lifecycle {
    prevent_destroy = false
  }

  depends_on = [
    azurerm_linux_virtual_machine.linux_vm,
    null_resource.start_linux_vms_before_extension_destroy
  ]
}

#   FIXED: DCR Association for Windows VMs
resource "azurerm_monitor_data_collection_rule_association" "windows_vm_dcr" {
  for_each = var.windows_events_dcr_id != null ? {
    for k, v in var.windows_vms : k => v
    if lookup(v, "enable_azure_monitor_agent", true)
  } : {}

  name                    = "dcra-${each.key}-windows-events"
  target_resource_id      = azurerm_windows_virtual_machine.win_vm[each.key].id
  data_collection_rule_id = var.windows_events_dcr_id
  description             = "Association for Windows security events collection"

  depends_on = [
    azurerm_windows_virtual_machine.win_vm,
    azurerm_virtual_machine_extension.ama_windows
  ]
}

# ✅ ENHANCED: Generic extensions with better lifecycle management
resource "azurerm_virtual_machine_extension" "generic_ext" {
  for_each = {
    for k, v in var.vm_extensions : k => v
    if contains(keys(var.windows_vms), v.virtual_machine_name) || contains(keys(var.linux_vms), v.virtual_machine_name)
  }

  name = each.value.name
  virtual_machine_id = try(
    azurerm_windows_virtual_machine.win_vm[each.value.virtual_machine_name].id,
    azurerm_linux_virtual_machine.linux_vm[each.value.virtual_machine_name].id,
    null
  )

  publisher            = each.value.publisher
  type                 = each.value.type
  type_handler_version = each.value.type_handler_version

  settings = each.value.settings != null ? (
    can(jsondecode(each.value.settings)) ? each.value.settings : jsonencode(each.value.settings)
  ) : null

  protected_settings = each.value.protected_settings != null ? (
    can(jsondecode(each.value.protected_settings)) ? each.value.protected_settings : jsonencode(each.value.protected_settings)
  ) : null

  tags = lookup(each.value, "tags", {})

  # ✅ CRITICAL: Prevent unnecessary recreation
  lifecycle {
    prevent_destroy = false
    create_before_destroy = false
    ignore_changes = [
      # Ignore changes that would cause recreation
      settings,
      protected_settings,
      type_handler_version
    ]
  }

  # ✅ AGGRESSIVE timeouts to prevent hanging
  # timeouts {
  #   create = "10m"
  #   update = "10m"
  #   delete = "3m"
  # }

  depends_on = [
    azurerm_windows_virtual_machine.win_vm,
    azurerm_linux_virtual_machine.linux_vm,
    null_resource.ensure_vm_running_before_extensions
  ]
}

# ✅ ENHANCED: VM Auto-Start with short timeouts
resource "azurerm_virtual_machine_extension" "vm_auto_start" {
  for_each = {
    for k, v in var.windows_vms : k => v
    if !contains([for ext_key, ext_val in var.vm_extensions : ext_val.virtual_machine_name], k)
  }

  name                       = "${each.value.name_prefix}-AutoStart"
  virtual_machine_id         = azurerm_windows_virtual_machine.win_vm[each.key].id
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.10"
  auto_upgrade_minor_version = true

  settings = jsonencode({
    commandToExecute = "powershell.exe -ExecutionPolicy Bypass -Command \"try { Set-Service -Name TermService -StartupType Automatic -ErrorAction Stop; Start-Service -Name TermService -ErrorAction Stop; Enable-NetFirewallRule -DisplayGroup 'Remote Desktop' -ErrorAction SilentlyContinue; Set-ItemProperty -Path 'HKLM:\\System\\CurrentControlSet\\Control\\Terminal Server' -Name 'fDenyTSConnections' -Value 0 -ErrorAction Stop; netsh advfirewall firewall set rule group='Remote Desktop' new enable=yes; Write-Host 'RDP configured successfully'; exit 0 } catch { Write-Host 'Error:' $_.Exception.Message; exit 1 }\""
  })

  # ✅ CRITICAL: Short timeouts to prevent hanging
  # timeouts {
  #   create = "8m"
  #   update = "8m"
  #   delete = "2m"   # ✅ VERY SHORT delete timeout
  # }

  tags = {
    Purpose = "AutoStartRDPConfiguration"
  }

  lifecycle {
    prevent_destroy = false
    create_before_destroy = false
  }

  depends_on = [
    azurerm_windows_virtual_machine.win_vm,
    null_resource.start_windows_vms_before_extension_destroy
  ]
}

# ✅ ADD: Ensure VM is running after deployment
# resource "null_resource" "ensure_vm_running" {
#   for_each = var.windows_vms

#   triggers = {
#     vm_id          = azurerm_windows_virtual_machine.win_vm[each.key].id
#     vm_name        = azurerm_windows_virtual_machine.win_vm[each.key].name
#     resource_group = var.resource_group_name
#   }

#   provisioner "local-exec" {
#     command = <<-EOT
#       echo "Ensuring VM ${each.value.name_prefix} is running..."
#       az vm start --name ${self.triggers.vm_name} --resource-group ${self.triggers.resource_group} || echo "VM may already be running"
      
#       # Wait for VM to be fully ready
#       echo "Waiting for VM to be ready..."
#       sleep 60
      
#       # Check VM status
#       az vm get-instance-view --name ${self.triggers.vm_name} --resource-group ${self.triggers.resource_group} --query "instanceView.statuses[?code=='PowerState/running']" --output table
#     EOT
#   }

#   depends_on = [
#     azurerm_windows_virtual_machine.win_vm,
#     azurerm_virtual_machine_extension.vm_auto_start
#   ]
# }

# ✅ ADD: RDP Service Health Check
# resource "null_resource" "rdp_health_check" {
#   for_each = var.windows_vms

#   triggers = {
#     vm_id          = azurerm_windows_virtual_machine.win_vm[each.key].id
#     vm_name        = azurerm_windows_virtual_machine.win_vm[each.key].name
#     resource_group = var.resource_group_name
#   }

#   provisioner "local-exec" {
#     command = <<-EOT
#       echo "Checking RDP service status for ${each.value.name_prefix}..."
      
#       # Run command to check RDP service status
#       az vm run-command invoke \
#         --name ${self.triggers.vm_name} \
#         --resource-group ${self.triggers.resource_group} \
#         --command-id RunPowerShellScript \
#         --scripts "Get-Service TermService | Select-Object Name, Status, StartType; Get-NetFirewallRule -DisplayName '*Remote Desktop*' | Select-Object DisplayName, Enabled, Direction" \
#         --output table || echo "Could not check RDP status"
#     EOT
#   }

#   depends_on = [
#     null_resource.ensure_vm_running
#   ]
# }

# ✅ NEW: Ensure VMs are running before ANY extension operations
# resource "null_resource" "ensure_vm_running_before_extensions" {
#   for_each = merge(var.windows_vms, var.linux_vms)

#   triggers = {
#     vm_id = try(
#       azurerm_windows_virtual_machine.win_vm[each.key].id,
#       azurerm_linux_virtual_machine.linux_vm[each.key].id,
#       ""
#     )
#     vm_name = try(
#       azurerm_windows_virtual_machine.win_vm[each.key].name,
#       azurerm_linux_virtual_machine.linux_vm[each.key].name,
#       ""
#     )
#     resource_group = var.resource_group_name
#     timestamp      = timestamp()
#   }

#   # Start VM before ANY extension operations (create, update, or destroy)
#   provisioner "local-exec" {
#     command = <<-EOT
#       echo "🚀 Ensuring VM ${self.triggers.vm_name} is running before extension operations..."
      
#       # Check if Azure CLI is available
#       if ! command -v az >/dev/null 2>&1; then
#         echo "Azure CLI not found - skipping VM start"
#         exit 0
#       fi
      
#       # Start the VM
#       echo "Starting VM: ${self.triggers.vm_name}"
#       az vm start --ids "${self.triggers.vm_id}" --no-wait || {
#         echo "Failed to start VM with ID, trying with name..."
#         az vm start --name "${self.triggers.vm_name}" --resource-group "${self.triggers.resource_group}" --no-wait || {
#           echo "VM start failed - VM might already be running or deleted"
#           exit 0
#         }
#       }
      
#       # Wait for VM to be running
#       echo "Waiting for VM to be running..."
#       timeout 120 bash -c '
#         while true; do
#           status=$(az vm get-instance-view --ids "${self.triggers.vm_id}" --query "instanceView.statuses[?code=='\''PowerState/running'\''].displayStatus" -o tsv 2>/dev/null || echo "")
#           if [ "$status" = "VM running" ]; then
#             echo "✅ VM is now running"
#             break
#           fi
#           echo "VM status: $status - waiting..."
#           sleep 10
#         done
#       ' || echo "Timeout waiting for VM - proceeding anyway"
      
#       echo "✅ VM preparation completed for ${self.triggers.vm_name}"
#     EOT
#   }

#   # Also run on destroy to ensure VM is running before extension cleanup
#   provisioner "local-exec" {
#     when    = destroy
#     command = <<-EOT
#       echo "🚀 Starting VM ${self.triggers.vm_name} before extension cleanup..."
      
#       if ! command -v az >/dev/null 2>&1; then
#         echo "Azure CLI not found - skipping"
#         exit 0
#       fi
      
#       # Start VM before extension cleanup
#       az vm start --ids "${self.triggers.vm_id}" --no-wait || {
#         az vm start --name "${self.triggers.vm_name}" --resource-group "${self.triggers.resource_group}" --no-wait || {
#           echo "Could not start VM - might be deleted already"
#           exit 0
#         }
#       }
      
#       # Short wait for VM to be ready
#       timeout 60 bash -c '
#         while true; do
#           status=$(az vm get-instance-view --ids "${self.triggers.vm_id}" --query "instanceView.statuses[?code=='\''PowerState/running'\''].displayStatus" -o tsv 2>/dev/null || echo "")
#           if [ "$status" = "VM running" ]; then
#             echo "✅ VM is running"
#             break
#           fi
#           sleep 5
#         done
#       ' || echo "Proceeding with extension cleanup"
#     EOT
#   }

#   depends_on = [
#     azurerm_windows_virtual_machine.win_vm,
#     azurerm_linux_virtual_machine.linux_vm
#   ]
# }

# # ✅ NEW: Start Windows VMs before extension destroy
# resource "null_resource" "start_windows_vms_before_extension_destroy" {
#   for_each = var.windows_vms

#   triggers = {
#     vm_id          = azurerm_windows_virtual_machine.win_vm[each.key].id
#     vm_name        = azurerm_windows_virtual_machine.win_vm[each.key].name
#     resource_group = var.resource_group_name
#   }

#   provisioner "local-exec" {
#     when    = destroy
#     command = <<-EOT
#       echo "🚀 Starting Windows VM ${self.triggers.vm_name} before extension destroy..."
      
#       if ! command -v az >/dev/null 2>&1; then
#         echo "Azure CLI not found - skipping"
#         exit 0
#       fi
      
#       # Start VM
#       az vm start --ids "${self.triggers.vm_id}" --no-wait || {
#         echo "Could not start VM - might be deleted already"
#         exit 0
#       }
      
#       # Wait briefly for VM to start
#       sleep 30
#       echo "✅ Windows VM start process completed"
#     EOT
#   }

#   depends_on = [azurerm_windows_virtual_machine.win_vm]
# }

# # ✅ NEW: Start Linux VMs before extension destroy
# resource "null_resource" "start_linux_vms_before_extension_destroy" {
#   for_each = var.linux_vms

#   triggers = {
#     vm_id          = azurerm_linux_virtual_machine.linux_vm[each.key].id
#     vm_name        = azurerm_linux_virtual_machine.linux_vm[each.key].name
#     resource_group = var.resource_group_name
#   }

#   provisioner "local-exec" {
#     when    = destroy
#     command = <<-EOT
#       echo "🚀 Starting Linux VM ${self.triggers.vm_name} before extension destroy..."
      
#       if ! command -v az >/dev/null 2>&1; then
#         echo "Azure CLI not found - skipping"
#         exit 0
#       fi
      
#       # Start VM
#       az vm start --ids "${self.triggers.vm_id}" --no-wait || {
#         echo "Could not start VM - might be deleted already"
#         exit 0
#       }
      
#       # Wait briefly for VM to start
#       sleep 30
#       echo "✅ Linux VM start process completed"
#     EOT
#   }

#   depends_on = [azurerm_linux_virtual_machine.linux_vm]
# }
