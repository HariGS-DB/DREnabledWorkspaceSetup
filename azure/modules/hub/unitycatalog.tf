
# Define a Databricks Metastore resource
resource "databricks_metastore" "this" {

  name = "uc-metastore-${var.resource_suffix}"
  storage_root = ""
  region        = azurerm_resource_group.this.location
  force_destroy = true
}

data "databricks_group" "account_admin_group" {
  display_name = var.account_admin
}

data "databricks_group" "metastore_admin_group" {
  display_name = var.metastore_admin
}

resource "databricks_group_role" "account_admin" {
  group_id = data.databricks_group.account_admin_group.id
  role     = var.account_admin
}

resource "databricks_group_role" "metastore_admin" {
  group_id = data.databricks_group.metastore_admin_group.id
  role     = var.metastore_admin
}