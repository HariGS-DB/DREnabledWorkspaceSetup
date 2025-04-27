provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

provider "databricks" {
  alias      = "mws"
  host       = "https://accounts.azuredatabricks.net"
  account_id = var.databricks_account_id
}

provider "databricks" {
  alias      = "spoke1"
  host       = module.spoke.workspace_urls
  account_id = var.databricks_account_id
}
