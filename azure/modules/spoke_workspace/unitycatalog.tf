

# Define an Azure Databricks access connector resource
resource "azurerm_databricks_access_connector" "unity_catalog" {

  name                = "databricks-mi-${var.resource_suffix}"
  resource_group_name = var.spoke_resource_group_name
  location            = var.location
  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}



# Define an Azure Storage Container resource
resource "azurerm_storage_container" "unity_catalog" {

  name                  = "default"
  storage_account_id    = var.catalog_storage.id
  container_access_type = "private"
}

# Define an Azure Storage Container resource for external delta table
resource "azurerm_storage_container" "external_tables_delta" {
  name                  = "external"
  storage_account_id    = var.catalog_storage.id
  container_access_type = "private"
}

# Define an Azure Storage Container resource for external volume
resource "azurerm_storage_container" "external_volume" {
  name                  = "externalvolume"
  storage_account_id    = var.volume_storage.id
  container_access_type = "private"
}

# Define an Azure role assignment resource
resource "azurerm_role_assignment" "this" {

  scope                = var.catalog_storage.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_databricks_access_connector.unity_catalog.identity[0].principal_id
}

# Define an Azure role assignment resource
resource "azurerm_role_assignment" "volume_storage_access" {

  scope                = var.volume_storage.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_databricks_access_connector.unity_catalog.identity[0].principal_id
}

# Grant DR access connector permissions on production catalog storage for cross-workspace Unity Catalog operations
resource "azurerm_role_assignment" "prod_catalog_storage_access" {
  count = var.dr && var.prod_catalog_storage != "" ? 1 : 0

  scope                = var.prod_catalog_storage  
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_databricks_access_connector.unity_catalog.identity[0].principal_id
  
  # Ensure this only runs after the access connector is created
  depends_on = [azurerm_databricks_access_connector.unity_catalog]
}


resource "databricks_storage_credential" "catalog_credential" {
  name                 = "databricks-${var.resource_suffix}-credential"
  azure_managed_identity {
    access_connector_id = azurerm_databricks_access_connector.unity_catalog.id
  }

}


resource "databricks_external_location" "catalog_location" {
  name = "databricks-catalog-location"
  url = format("abfss://%s@%s.dfs.core.windows.net",
    azurerm_storage_container.unity_catalog.name,
    var.catalog_storage.name)

  credential_name = databricks_storage_credential.catalog_credential.id
  comment         = "Managed by TF"
  depends_on = [databricks_storage_credential.catalog_credential, azurerm_storage_container.unity_catalog]

}

resource "databricks_external_location" "external_deltatable_location" {
  name = "databricks-external-deltatable-location"
  url = format("abfss://%s@%s.dfs.core.windows.net",
    azurerm_storage_container.external_tables_delta.name,
    var.catalog_storage.name)

  credential_name = databricks_storage_credential.catalog_credential.id
  comment         = "Managed by TF"
  depends_on = [databricks_storage_credential.catalog_credential, azurerm_storage_container.external_tables_delta]

}

resource "databricks_external_location" "external_volume_location" {
  name = "databricks-external-volume-location"
  url = format("abfss://%s@%s.dfs.core.windows.net",
    azurerm_storage_container.external_volume.name,
    var.volume_storage.name)

  credential_name = databricks_storage_credential.catalog_credential.id
  comment         = "Managed by TF"
  depends_on = [databricks_storage_credential.catalog_credential, azurerm_storage_container.external_volume]

}

# External location for production catalog storage external container (DR mode only)
resource "databricks_external_location" "prod_external_location" {
  count = var.dr && var.prod_catalog_storage != "" ? 1 : 0

  name = "prod-external-deltatable-location"
  url = format("abfss://external@%s.dfs.core.windows.net",
    regex("[^/]+$", var.prod_catalog_storage))  # Extract storage account name from resource ID

  credential_name = databricks_storage_credential.catalog_credential.id
  comment         = "Production catalog external container - Managed by TF for DR operations"
  
  depends_on = [
    databricks_storage_credential.catalog_credential,
    azurerm_role_assignment.prod_catalog_storage_access
  ]
}




resource "databricks_catalog" "catalog" {
  name = "databrickscatalog1"
  storage_root = format("abfss://%s@%s.dfs.core.windows.net",
    azurerm_storage_container.unity_catalog.name,
    var.catalog_storage.name)
  depends_on = [databricks_external_location.catalog_location]
}

resource "databricks_grants" "catalog_admin" {
  catalog = databricks_catalog.catalog.name
  grant {
    principal  = var.catalog_admin
    privileges = ["ALL_PRIVILEGES"]
  }

}