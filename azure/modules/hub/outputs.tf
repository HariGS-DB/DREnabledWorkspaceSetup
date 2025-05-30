output "firewall_name" {
  value       = length(azurerm_firewall.this) > 0 ? azurerm_firewall.this[0].name : ""
  description = "The name of the Azure Firewall resource."
}

output "ipgroup_id" {
  value       = azurerm_ip_group.this.id
  description = "The unique ID of the Azure IP Group."
}

output "route_table_id" {
  value       = azurerm_route_table.this.id
  description = "The unique ID of the Azure Route Table."
}

output "key_vault_id" {
  value       = length(azurerm_key_vault.this) > 0 ? azurerm_key_vault.this[0].id : null
  description = "The ID of the Azure Key Vault, if created. Returns null if no Key Vault is created."
}

output "managed_disk_key_id" {
  value       = length(azurerm_key_vault_key.managed_disk) > 0 ? azurerm_key_vault_key.managed_disk[0].id : null
  description = "The ID of the Key Vault key used for managed disks, if available. Returns null if not created."
}

output "managed_services_key_id" {
  value       = length(azurerm_key_vault_key.managed_services) > 0 ? azurerm_key_vault_key.managed_services[0].id : null
  description = "The ID of the Key Vault key used for managed services, if available. Returns null if not created."
}

output "vnet_id" {
  value       = azurerm_virtual_network.this.id
  description = "The unique ID of the Azure Virtual Network."
}

output "vnet_name" {
  value       = azurerm_virtual_network.this.name
  description = "The name of the Azure Virtual Network."
}

output "metastore_id" {
  value       = databricks_metastore.this.id
  description = "The unique ID of the Databricks Metastore."
}


output "resource_group_name" {
  value       = azurerm_resource_group.this.name
  description = "The name of the Azure Resource Group."
}


output "ncc_id" {
  value       = databricks_mws_network_connectivity_config.this.network_connectivity_config_id
  description = "The ID of the hub regional Network Connectivity Config."
}
