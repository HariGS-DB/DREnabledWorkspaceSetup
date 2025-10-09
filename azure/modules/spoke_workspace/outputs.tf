# DR Serverless Warehouse Output
output "dr_warehouse_info" {
  description = "Information about the DR serverless warehouse"
  value = var.dr ? {
    warehouse_id = databricks_sql_endpoint.dr_warehouse[0].id
    warehouse_name = databricks_sql_endpoint.dr_warehouse[0].name
  } : null
}
