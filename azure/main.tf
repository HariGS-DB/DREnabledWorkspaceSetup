locals {
  hub_cidr_prefix     = split("/", var.hub_vnet_cidr)[1]
  firewall_newbits    = 26 - local.hub_cidr_prefix
  privatelink_newbits = 24 - local.hub_cidr_prefix
}

module "subnet_addrs" {
  source  = "hashicorp/subnets/cidr"
  version = "~>1.0"

  base_cidr_block = var.hub_vnet_cidr
  networks = [
    {
      name     = "privatelink"
      new_bits = local.privatelink_newbits
    },
    {
      name     = "firewall"
      new_bits = local.firewall_newbits
    },
  ]
}
# Define module "hub" with the source "./modules/azure_hub"
# Pass the required variables to the module
module "hub" {
  source          = "./modules/hub"
  location        = var.location
  hub_vnet_cidr   = var.hub_vnet_cidr
  subnet_map      = module.subnet_addrs.network_cidr_blocks
  client_config   = data.azurerm_client_config.current
  public_repos    = var.public_repos
  tags            = var.tags
  resource_suffix = var.hub_resource_suffix
  account_admin   = "HSAccountAdmin"
  metastore_admin = "HSMetastoreAdmin"


  #options
  is_kms_enabled      = true
  is_firewall_enabled = true
  providers           = { databricks = databricks.mws }

}
