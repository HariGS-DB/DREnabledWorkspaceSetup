databricks_account_id   = "ccb842e7-2376-4152-b0b0-29fa952379b8"
hub_resource_suffix     = "hshub"
hub_vnet_cidr           = "10.0.0.0/22"
location                = "northeurope"
tags = {
  Owner = "hari.selvarajan@databricks.com"
}
spoke_config = {
  spoke1 = {
    resource_suffix = "spoke1"
    cidr            = "10.1.0.0/20"
    tags            = {
      environment = "test"
    }
  }
}
subscription_id = "edd4cc45-85c7-4aec-8bf5-648062d519bf"
container_name="tfstate"


