
# Define a Databricks Metastore resource
resource "databricks_metastore" "this" {

  name = "uc-metastore-${var.resource_suffix}"
  storage_root = ""
  region        = azurerm_resource_group.this.location
  force_destroy = true
}
