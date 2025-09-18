
# Define module "spoke" with a for_each loop to iterate over each spoke configuration
module "spoke" {


  source = "./modules/spoke"

  # Pass the required variables to the module
  resource_suffix = var.spoke_suffix
  vnet_cidr       = "10.1.0.0/20"
  tags            = var.tags

  location                = var.location
  route_table_id          = module.hub.route_table_id
  metastore_id            = module.hub.metastore_id
  hub_vnet_name           = module.hub.vnet_name
  hub_resource_group_name = module.hub.resource_group_name
  hub_vnet_id             = module.hub.vnet_id
  key_vault_id            = module.hub.key_vault_id
  ipgroup_id              = module.hub.ipgroup_id
  managed_disk_key_id     = module.hub.managed_disk_key_id
  managed_services_key_id = module.hub.managed_services_key_id
  ncc_id                  = module.hub.ncc_id


  #options
  is_kms_enabled                   = true
  is_frontend_private_link_enabled = false
  boolean_create_private_dbfs      = true

  depends_on = [module.hub]
  providers  = { databricks = databricks.mws }
}

module "spoke_workspace" {


  source = "./modules/spoke_workspace"

  # Pass the required variables to the module
  resource_suffix = var.spoke_suffix

  tags = var.spoke_tag

  location                  = var.location
  catalog_storage           = module.spoke.catalog_storage
  volume_storage            = module.spoke.volume_storage
  catalog_admin             = "Catalog1Admin"
  metastore_id              = module.hub.metastore_id
  spoke_resource_group_name = module.spoke.resource_group_name
  dr                        = var.dr

  depends_on = [module.spoke]
  providers  = { databricks = databricks.spoke1 }
}
