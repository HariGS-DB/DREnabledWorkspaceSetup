
resource "databricks_mws_ncc_private_endpoint_rule" "storage" {
  network_connectivity_config_id = var.ncc_id
  resource_id                    = azurerm_storage_account.unity_catalog.id
  group_id                       = "dfs"
}
