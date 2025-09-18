databricks_account_id = "ccb842e7-2376-4152-b0b0-29fa952379b8"
hub_vnet_cidr         = "10.0.0.0/22"
tags = {
  Owner = "hari.selvarajan@databricks.com"
}
hub_resource_suffix = "hsdrhub"
location            = "northeurope"
subscription_id     = "edd4cc45-85c7-4aec-8bf5-648062d519bf"

spoke_suffix = "prodspoke"
spoke_tag    = { environment = "prod" }
dr           = false