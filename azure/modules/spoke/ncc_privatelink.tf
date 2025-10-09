
resource "databricks_mws_ncc_private_endpoint_rule" "storage" {
  network_connectivity_config_id = var.ncc_id
  resource_id                    = azurerm_storage_account.unity_catalog.id
  group_id                       = "dfs"
}

# DR: NCC Private Endpoint rule for Production Catalog Storage
# This rule allows DR workspace serverless compute to access production catalog storage via DFS protocol
resource "databricks_mws_ncc_private_endpoint_rule" "prod_catalog_storage_dfs" {
  count = var.dr && var.prod_catalog_storage != "" ? 1 : 0
  
  network_connectivity_config_id = var.ncc_id
  resource_id                    = jsondecode(var.prod_catalog_storage)
  group_id                       = "dfs"
}
