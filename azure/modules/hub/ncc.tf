resource "databricks_mws_network_connectivity_config" "this" {
  name   = "ncc-for-${var.resource_suffix}"
  region = azurerm_resource_group.this.location
}


