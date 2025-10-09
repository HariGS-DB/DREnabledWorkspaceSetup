# Automatic approval for existing NCC Private Endpoint connections
# This handles approval of connections created by the existing NCC rules

# This module uses Azure CLI commands to approve pending NCC private endpoint connections
# It avoids Terraform's for_each dependency issues by using a script-based approach

# Auto-approval using script approach to avoid for_each dependency issues
resource "null_resource" "approve_ncc_connections" {
  # Trigger when NCC rules change
  triggers = {
    dbfs_blob_rule = databricks_mws_ncc_private_endpoint_rule.dbfs_blob.id
    dbfs_dfs_rule  = databricks_mws_ncc_private_endpoint_rule.dbfs_dfs.id
    unity_catalog_rule = databricks_mws_ncc_private_endpoint_rule.storage.id
    # DR-specific triggers (only when DR is enabled)
    prod_catalog_dfs_rule = var.dr && var.prod_catalog_storage != "" ? databricks_mws_ncc_private_endpoint_rule.prod_catalog_storage_dfs[0].id : ""
  }

  # Wait for connections to be created before approval
  depends_on = [
    databricks_mws_ncc_private_endpoint_rule.dbfs_blob,
    databricks_mws_ncc_private_endpoint_rule.dbfs_dfs,
    databricks_mws_ncc_private_endpoint_rule.storage,
    # DR dependencies are handled automatically by Terraform when resources exist
  ]

  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for NCC private endpoint connections to be created..."
      sleep 30
      
      # Function to approve pending connections for a storage account
      approve_connections() {
        local storage_account_id="$1"
        local description="$2"
        
        echo "Checking storage account: $storage_account_id"
        
        # Get pending connections
        pending_connections=$(az rest \
          --method GET \
          --url "$storage_account_id?api-version=2023-01-01" \
          --query "properties.privateEndpointConnections[?properties.privateLinkServiceConnectionState.status=='Pending'].name" \
          --output tsv 2>/dev/null || echo "")
        
        if [ -n "$pending_connections" ]; then
          echo "$pending_connections" | while read -r connection_name; do
            if [ -n "$connection_name" ]; then
              echo "Approving connection: $connection_name"
              az rest \
                --method PUT \
                --url "$storage_account_id/privateEndpointConnections/$connection_name?api-version=2023-01-01" \
                --body '{"properties":{"privateLinkServiceConnectionState":{"status":"Approved","description":"'"$description"'"}}}' \
                --output none || echo "Failed to approve $connection_name"
            fi
          done
        else
          echo "No pending connections found for $storage_account_id"
        fi
      }
      
      # Approve DBFS storage account connections
      approve_connections "${data.azurerm_storage_account.dbfs.id}" "Auto-approved for Databricks Serverless Compute"
      
            # Approve Unity Catalog storage account connections  
            approve_connections "${azurerm_storage_account.unity_catalog.id}" "Auto-approved for Databricks Serverless Compute"
            
            # Approve Production Catalog storage account connections (DR mode only)
            if [ "${var.dr}" = "true" ] && [ -n "${var.prod_catalog_storage}" ] && [ "${var.prod_catalog_storage}" != "" ]; then
              echo "DR Mode: Approving production catalog storage connections..."
              PROD_STORAGE_ID="${var.prod_catalog_storage}"
              if [ -n "$PROD_STORAGE_ID" ] && [ "$PROD_STORAGE_ID" != "null" ]; then
                approve_connections "$PROD_STORAGE_ID" "Auto-approved for DR Unity Catalog replication"
              else
                echo "⚠️ Production storage account ID is empty or null: ${var.prod_catalog_storage}"
              fi
            fi
            
            echo "NCC private endpoint approval process completed"
    EOT
  }
}

# Output approval status
output "ncc_approval_status" {
  description = "Status of NCC private endpoint connection approvals"
  value = {
    dbfs_storage = {
      storage_account_id = data.azurerm_storage_account.dbfs.id
      approval_enabled = true
    }
    unity_catalog = {
      storage_account_id = azurerm_storage_account.unity_catalog.id
      approval_enabled = true
    }
    prod_catalog_dr = {
      dr_mode_enabled = var.dr
      prod_storage_configured = var.prod_catalog_storage != ""
      approval_enabled = var.dr && var.prod_catalog_storage != ""
    }
    approval_script_status = null_resource.approve_ncc_connections.id
  }
}
