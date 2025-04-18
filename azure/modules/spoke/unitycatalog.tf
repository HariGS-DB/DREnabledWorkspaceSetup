locals {
  # If the user provides a storage account name, use it. If they do not, check if the resource_suffix was left defaulted. If it was, generate a unique storage account name, else use a non-unique storage account name (assuming the resource suffix is unique).
  storage_account_name = coalesce(var.storage_account_name, var.resource_suffix == "hub" ? "${module.naming.storage_account.name_unique}uc" : "${module.naming.storage_account.name}uc")
}

# Define an Azure Databricks access connector resource
resource "azurerm_databricks_access_connector" "unity_catalog" {

  name                = "databricks-mi-${var.resource_suffix}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# Define an Azure Storage Account resource
resource "azurerm_storage_account" "unity_catalog" {

  name                          = local.storage_account_name
  resource_group_name           = azurerm_resource_group.this.name
  location                      = azurerm_resource_group.this.location
  account_tier                  = "Standard"
  account_replication_type      = "GRS"
  is_hns_enabled                = true
  public_network_access_enabled = false
  network_rules {
    default_action = "Deny"
    bypass         = ["None"]
    private_link_access {
      endpoint_resource_id = azurerm_databricks_access_connector.unity_catalog.id
    }
  }

  tags = var.tags
}

# Define an Azure Storage Container resource
resource "azurerm_storage_container" "unity_catalog" {

  name                  = "default"
  storage_account_id    = azurerm_storage_account.unity_catalog.id
  container_access_type = "private"
}

# Define an Azure role assignment resource
resource "azurerm_role_assignment" "this" {

  scope                = azurerm_storage_account.unity_catalog.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_databricks_access_connector.unity_catalog.identity[0].principal_id
}
