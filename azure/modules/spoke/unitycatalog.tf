locals {
  # If the user provides a storage account name, use it. If they do not, check if the resource_suffix was left defaulted. If it was, generate a unique storage account name, else use a non-unique storage account name (assuming the resource suffix is unique).
  catalog_storage_account_name = "${module.naming.storage_account.name}uc"
  external_storage_account_name = "${module.naming.storage_account.name}volume"
}
#
## Define an Azure Databricks access connector resource
#resource "azurerm_databricks_access_connector" "unity_catalog" {
#
#  name                = "databricks-mi-${var.resource_suffix}"
#  resource_group_name = azurerm_resource_group.this.name
#  location            = azurerm_resource_group.this.location
#  identity {
#    type = "SystemAssigned"
#  }
#
#  tags = var.tags
#}
#
# Define an Azure Storage Account resource
resource "azurerm_storage_account" "unity_catalog" {

  name                          = local.catalog_storage_account_name
  resource_group_name           = azurerm_resource_group.this.name
  location                      = azurerm_resource_group.this.location
  account_tier                  = "Standard"
  account_replication_type      = "LRS"
  is_hns_enabled                = true
  public_network_access_enabled = false


  tags = var.tags
}

resource "azurerm_storage_account" "external_storage" {

  name                          = local.external_storage_account_name
  resource_group_name           = azurerm_resource_group.this.name
  location                      = azurerm_resource_group.this.location
  account_tier                  = "Standard"
  account_replication_type      = "GRS"
  is_hns_enabled                = true
  public_network_access_enabled = false


  tags = var.tags
}
#
## Define an Azure Storage Container resource
#resource "azurerm_storage_container" "unity_catalog" {
#
#  name                  = "default"
#  storage_account_id    = azurerm_storage_account.unity_catalog.id
#  container_access_type = "private"
#}
#
## Define an Azure role assignment resource
#resource "azurerm_role_assignment" "this" {
#
#  scope                = azurerm_storage_account.unity_catalog.id
#  role_definition_name = "Storage Blob Data Contributor"
#  principal_id         = azurerm_databricks_access_connector.unity_catalog.identity[0].principal_id
#}
#
#
#resource "databricks_storage_credential" "catalog_credential" {
#  name                 = "databricks-${var.resource_suffix}-credential"
#  azure_managed_identity {
#    access_connector_id = azurerm_databricks_access_connector.unity_catalog.id
#  }
#  depends_on = [
#    databricks_metastore_assignment.this
#  ]
#}
#
#
#resource "databricks_external_location" "catalog_location" {
#  name = "databricks-${var.resource_suffix}-catalog-location"
#  url = format("abfss://%s@%s.dfs.core.windows.net",
#    azurerm_storage_container.unity_catalog.name,
#    azurerm_storage_account.unity_catalog.name)
#
#  credential_name = databricks_storage_credential.catalog_credential.id
#  comment         = "Managed by TF"
#  depends_on = [
#    databricks_metastore_assignment.this
#  ]
#}
#
#
#
#
#resource "databricks_catalog" "catalog" {
#  name = "databricks-${var.resource_suffix}-catalog"
#  storage_root = format("abfss://%s@%s.dfs.core.windows.net",
#    azurerm_storage_container.unity_catalog.name,
#    azurerm_storage_account.unity_catalog.name)
#  depends_on = [databricks_metastore_assignment.this]
#}
#
#resource "databricks_grants" "catalog_admin" {
#  catalog = databricks_catalog.catalog.name
#  grant {
#    principal  = var.catalog_admin
#    privileges = ["ALL_PRIVILEGES"]
#  }
#
#}