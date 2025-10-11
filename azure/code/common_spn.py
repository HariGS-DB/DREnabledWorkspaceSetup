# Databricks notebook source
"""
Common module for DR sync operation using Service Principal authentication
"""

from databricks.sdk import WorkspaceClient
from databricks.sdk.core import ClientCredentials

# Configuration parameters
num_exec = 10  # Number of concurrent workers
response_backoff = 5  # Backoff time in seconds for polling operations

# Secret scope and keys for Service Principal authentication
SECRET_SCOPE = "dr-service-principal"
CLIENT_ID_KEY = "client-id"
CLIENT_SECRET_KEY = "client-secret"
PROD_WORKSPACE_URL_KEY = "prod-workspace-url"
DR_WAREHOUSE_ID_KEY = "dr-warehouse-id"
DR_WORKSPACE_URL_KEY = "dr-workspace-url"
PROD_METASTORE_ID_KEY = "prod-metastore-id"


def get_spn_credentials():
    """Get Service Principal credentials from Databricks secrets."""
    try:
        client_id = dbutils.secrets.get(scope=SECRET_SCOPE, key=CLIENT_ID_KEY)
        client_secret = dbutils.secrets.get(scope=SECRET_SCOPE, key=CLIENT_SECRET_KEY)
        return client_id, client_secret
    except Exception as e:
        raise RuntimeError(f"Failed to retrieve SPN credentials from secrets: {str(e)}")


def get_workspace_urls():
    """Get workspace URLs from Databricks secrets."""
    try:
        source_host = dbutils.secrets.get(scope=SECRET_SCOPE, key=PROD_WORKSPACE_URL_KEY)
        target_host = dbutils.secrets.get(scope=SECRET_SCOPE, key=DR_WORKSPACE_URL_KEY)
        return source_host, target_host
    except Exception as e:
        raise RuntimeError(f"Failed to retrieve workspace URLs from secrets: {str(e)}")


def get_dr_warehouse_id():
    """Get DR warehouse ID from Databricks secrets."""
    try:
        warehouse_id = dbutils.secrets.get(scope=SECRET_SCOPE, key=DR_WAREHOUSE_ID_KEY)
        return warehouse_id
    except Exception as e:
        raise RuntimeError(f"Failed to retrieve DR warehouse ID from secrets: {str(e)}")


def get_prod_metastore_id():
    """Get production metastore ID from Databricks secrets."""
    try:
        metastore_id = dbutils.secrets.get(scope=SECRET_SCOPE, key=PROD_METASTORE_ID_KEY)
        return metastore_id
    except Exception as e:
        print(f"⚠️  Warning: Could not retrieve production metastore ID from secrets: {str(e)}")
        return None


def create_workspace_client(workspace_url):
    """
    Create a WorkspaceClient using Service Principal authentication.
    
    Args:
        workspace_url (str): The Databricks workspace URL
        
    Returns:
        WorkspaceClient: Authenticated workspace client
    """
    try:
        client_id, client_secret = get_spn_credentials()
        
        
        
        # Create workspace client
        client = WorkspaceClient(
            host=workspace_url,
            client_id=client_id,
            client_secret=client_secret
        )
        
        return client
        
    except Exception as e:
        raise RuntimeError(f"Failed to create WorkspaceClient for {workspace_url}: {str(e)}")


# Get workspace URLs from secrets
source_host, target_host = get_workspace_urls()

# Get DR warehouse ID from secrets
dr_warehouse_id = get_dr_warehouse_id()

# Get production metastore ID from secrets (optional for cross-workspace operations)
prod_metastore_id = get_prod_metastore_id()

# Create authenticated workspace clients
print(f"🔗 Connecting to source workspace: {source_host}")
print(f"🔗 Connecting to target workspace: {target_host}")
print(f"🏭 Using DR warehouse: {dr_warehouse_id}")
if prod_metastore_id:
    print(f"🗄️ Production metastore available: {prod_metastore_id}")
else:
    print("ℹ️  Production metastore ID not available (operating in single workspace mode)")

try:
    w_source = create_workspace_client(source_host)
    w_target = create_workspace_client(target_host)
    
    # Test connectivity
    source_user = w_source.current_user.me()
    target_user = w_target.current_user.me()
    
    print(f"✅ Source workspace connected as: {source_user.user_name}")
    print(f"✅ Target workspace connected as: {target_user.user_name}")
    print(f"✅ DR warehouse ID retrieved: {dr_warehouse_id}")
    
except Exception as e:
    print(f"❌ Failed to establish workspace connections: {str(e)}")
    raise

# Legacy compatibility - expose the workspace clients as expected by sync scripts
# These replace the old PAT token based clients
print("🔄 Service Principal authentication ready for DR sync operations")
