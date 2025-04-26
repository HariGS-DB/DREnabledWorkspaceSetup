
# Define a Databricks Metastore resource
resource "databricks_metastore" "this" {

  name = "uc-metastore-${var.resource_suffix}"
  storage_root = ""
  region        = azurerm_resource_group.this.location
  force_destroy = true
}

resource "databricks_group" "account_admin_group" {
  display_name = var.account_admin
}

resource "databricks_group" "metastore_admin_group" {
  display_name = var.metastore_admin
}

resource "databricks_group_role" "account_admin" {
  group_id = databricks_group.account_admin_group.id
  role     = databricks_group_role.account_admin
}

resource "databricks_group_role" "metastore_admin" {
  group_id = databricks_group.metastore_admin_group.id
  role     = databricks_group_role.metastore_admin
}