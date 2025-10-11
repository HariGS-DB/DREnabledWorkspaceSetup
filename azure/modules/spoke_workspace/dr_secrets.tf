# DR Secrets Management
# Creates Databricks secret scope and secrets for service principal authentication
# Only runs when DR mode is enabled and SPN credentials are provided

# Create secret scope for DR operations
resource "databricks_secret_scope" "dr_spn_scope" {
  count = var.dr && var.job_spn_client_id != "" && var.job_spn_client_secret != "" ? 1 : 0
  
  name = "dr-service-principal"
  
  initial_manage_principal = "users"
}

# Store service principal client ID
resource "databricks_secret" "spn_client_id" {
  count = var.dr && var.job_spn_client_id != "" && var.job_spn_client_secret != "" ? 1 : 0
  
  key          = "client-id"
  string_value = var.job_spn_client_id
  scope        = databricks_secret_scope.dr_spn_scope[0].name
}

# Store service principal client secret
resource "databricks_secret" "spn_client_secret" {
  count = var.dr && var.job_spn_client_id != "" && var.job_spn_client_secret != "" ? 1 : 0
  
  key          = "client-secret"
  string_value = var.job_spn_client_secret
  scope        = databricks_secret_scope.dr_spn_scope[0].name
}

# Store production workspace URL for cross-workspace operations
resource "databricks_secret" "prod_workspace_url" {
  count = var.dr && var.prod_workspace_url != "" ? 1 : 0
  
  key          = "prod-workspace-url"
  string_value = var.prod_workspace_url
  scope        = databricks_secret_scope.dr_spn_scope[0].name
}

# Store current (DR) workspace URL for reference
resource "databricks_secret" "dr_workspace_url" {
  count = var.dr && var.job_spn_client_id != "" && var.job_spn_client_secret != "" ? 1 : 0
  
  key          = "dr-workspace-url"
  string_value = var.workspace_url
  scope        = databricks_secret_scope.dr_spn_scope[0].name
}

# Store DR warehouse ID for sync operations
resource "databricks_secret" "dr_warehouse_id" {
  count = var.dr && var.job_spn_client_id != "" && var.job_spn_client_secret != "" ? 1 : 0
  
  key          = "dr-warehouse-id"
  string_value = databricks_sql_endpoint.dr_warehouse[0].id
  scope        = databricks_secret_scope.dr_spn_scope[0].name
}

# Store production metastore ID for cross-workspace Unity Catalog operations
resource "databricks_secret" "prod_metastore_id" {
  count = var.dr && var.prod_metastore_id != "" ? 1 : 0
  
  key          = "prod-metastore-id"
  string_value = var.prod_metastore_id
  scope        = databricks_secret_scope.dr_spn_scope[0].name
}
