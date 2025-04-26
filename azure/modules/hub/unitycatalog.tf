
# Define a Databricks Metastore resource
resource "databricks_metastore" "this" {

  name = "uc-metastore-${var.resource_suffix}"
  storage_root = ""
  region        = azurerm_resource_group.this.location
  force_destroy = true
  owner = var.metastore_admin
}

data "databricks_group" "account_admin_group" {
  display_name = var.account_admin
}



resource "databricks_group_role" "account_admin" {
  group_id = data.databricks_group.account_admin_group.id
  role     = "account_admin"
}
