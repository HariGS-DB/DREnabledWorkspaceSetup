output "hub_network_subnets" {
  description = "Subnets created in the hub network"
  value       = module.subnet_addrs.network_cidr_blocks
}

output "hub_resource_group_name" {
  description = "Name of created hub resource group"
  value       = module.hub.resource_group_name
}

output "spoke_workspace_info" {
  description = "URLs for the one (or more) deployed Databricks Workspaces"
  value       = module.spoke.workspace_urls
}

output "catalog_storage_info" {
  description = "Unity Catalog storage account ID"
  value       = module.spoke.catalog_storage.id
}

output "spoke_resource_group_name" {
  description = "Name of the spoke resource group"
  value       = module.spoke.resource_group_name
}

output "spoke_workspace_name" {
  description = "Name of the spoke Databricks workspace"
  value       = module.spoke.workspace_name
}

output "metastore_id" {
  description = "ID of the Databricks Unity Catalog metastore"
  value       = module.hub.metastore_id
}


# Global Metastore ID (Delta Sharing Identifier) Output
output "global_metastore_id" {
  description = "Global metastore ID (Delta Sharing identifier) from the current metastore"
  value       = data.databricks_current_metastore.this.metastore_info[0].global_metastore_id
}
