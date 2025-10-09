
variable "location" {
  type        = string
  description = "(Required) The location for the spoke deployment"
}


variable "metastore_id" {
  type        = string
  description = "(Required) The ID of the metastore to associate with the Databricks workspace"
}


variable "resource_suffix" {
  type        = string
  description = "(Required) Naming resource_suffix for resources"
}

variable "tags" {
  type        = map(string)
  description = "(Optional) Map of tags to attach to resources"
  default     = {}
}

variable "catalog_storage" {
  type = any
}

variable "volume_storage" {
  type = any
}
variable "dr" {
  type = bool
}


variable "spoke_resource_group_name" {
  type        = string
  default     = null
}
variable "catalog_admin" {
  type        = string
}

variable "job_spn_client_id" {
  type        = string
  description = "(Optional) Service Principal Client ID for job authentication and cross-workspace operations"
  default     = ""
  sensitive   = true
}

variable "job_spn_client_secret" {
  type        = string
  description = "(Optional) Service Principal Client Secret for job authentication and cross-workspace operations"
  default     = ""
  sensitive   = true
}

variable "prod_workspace_url" {
  type        = string
  description = "(Optional) Production workspace URL for DR configuration and cross-workspace operations"
  default     = ""
}

variable "workspace_url" {
  type        = string
  description = "(Required) Current workspace URL for DR configuration"
}
