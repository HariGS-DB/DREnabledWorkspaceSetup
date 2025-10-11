# DR Serverless Warehouse Output
output "dr_warehouse_info" {
  description = "Information about the DR serverless warehouse"
  value = var.dr ? {
    warehouse_id = databricks_sql_endpoint.dr_warehouse[0].id
    warehouse_name = databricks_sql_endpoint.dr_warehouse[0].name
  } : null
}

# Global Metastore ID (Delta Sharing Identifier) Output
output "global_metastore_id" {
  description = "Global metastore ID (Delta Sharing identifier) from the current metastore"
  value       = data.databricks_current_metastore.this.metastore_info
}
