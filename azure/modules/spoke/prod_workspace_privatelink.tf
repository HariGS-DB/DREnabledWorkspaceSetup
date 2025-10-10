
# Data source to get production workspace details by workspace URL
data "azurerm_databricks_workspace" "prod" {
  count = var.dr && var.prod_workspace_url != "" && var.prod_resource_group_name != "" ? 1 : 0
  
  workspace_url       = var.prod_workspace_url
  resource_group_name = var.prod_resource_group_name
}

# Private endpoint for production workspace backend connection (databricks_ui_api)
resource "azurerm_private_endpoint" "prod_workspace_backend" {
  count = var.dr && var.prod_workspace_url != "" && var.prod_resource_group_name != "" ? 1 : 0
  
  name                = "${module.naming.private_endpoint.name_unique}-prod-backend"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  subnet_id           = azurerm_subnet.privatelink.id

  private_service_connection {
    name                           = "ple-${var.resource_suffix}-prod-backend"
    private_connection_resource_id = data.azurerm_databricks_workspace.prod[0].id
    is_manual_connection           = false
    subresource_names              = ["databricks_ui_api"]
  }

  private_dns_zone_group {
    name                 = "private-dns-zone-prod-backend"
    private_dns_zone_ids = [azurerm_private_dns_zone.backend.id]
  }

  depends_on = [azurerm_private_endpoint.backend]

  tags = var.tags
}
