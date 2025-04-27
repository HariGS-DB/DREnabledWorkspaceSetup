# Databricks notebook source
import sys
import time
import pandas as pd
from itertools import repeat
from databricks.sdk import WorkspaceClient
from databricks.sdk.service import sql as dbsql
from concurrent.futures import ThreadPoolExecutor
from databricks.sdk.service.sql import (
    Disposition,
    StatementState,
    CreateWarehouseRequestWarehouseType,
    ExecuteStatementRequestOnWaitTimeout,
)
from databricks.sdk.errors.platform import BadRequest
from databricks.sdk.service.catalog import (
    Privilege,
    PermissionsChange,
    CatalogType,
    TableType,
)
from databricks.sdk.service.sharing import (
    AuthenticationType,
    SharedDataObjectUpdate,
    SharedDataObjectUpdateAction,
    SharedDataObject,
    SharedDataObjectStatus,
)
from common import (
    target_pat,
    target_host,
    source_pat,
    source_host,
    num_exec,
    dr_warehouse_id,
    response_backoff,
    metastore_id,
)


# helper function to clone a table from one catalog to another
def clone_table(
    w: WorkspaceClient, source_catalog, target_catalog, schema, table_name, warehouse
):
    print(f"Cloning table {source_catalog}.{schema}.{table_name}...")
    try:
        sqlstring = (
            f"CREATE OR REPLACE TABLE {target_catalog}.{schema}.{table_name} "
            f"DEEP CLONE {source_catalog}.{schema}.{table_name}"
        )

        resp = w.statement_execution.execute_statement(
            warehouse_id=warehouse,
            wait_timeout="0s",
            on_wait_timeout=ExecuteStatementRequestOnWaitTimeout("CONTINUE"),
            disposition=Disposition("EXTERNAL_LINKS"),
            statement=sqlstring,
        )
        print(resp.status)

        while resp.status.state in {StatementState.PENDING, StatementState.RUNNING}:
            resp = w.statement_execution.get_statement(resp.statement_id)
            time.sleep(response_backoff)

        if resp.status.state != StatementState.SUCCEEDED:
            return {
                "catalog": target_catalog,
                "schema": schema,
                "table_name": table_name,
                "status": f"FAIL: {resp.status.error.message}",
                "creation_time": time.time_ns(),
            }

        return {
            "catalog": target_catalog,
            "schema": schema,
            "table_name": table_name,
            "status": "SUCCESS",
            "creation_time": time.time_ns(),
        }

    except Exception as e:
        return {
            "catalog": target_catalog,
            "schema": schema,
            "table_name": table_name,
            "status": f"FAIL: {e}",
            "creation_time": time.time_ns(),
        }


write_results = False  # set to true to write status df to disk

# create the WorkspaceClients for source and target workspaces
w_source = WorkspaceClient(host=source_host, token=source_pat)
w_target = WorkspaceClient(host=target_host, token=target_pat)


# create the secondary metastore as a recipient
try:
    local_metastore_id = [
        r["current_metastore()"]
        for r in spark.sql("SELECT current_metastore()").collect()
    ][0]

    print(f"Creating recipient with id {local_metastore_id}...")
    recipient = w_source.recipients.create(
        name="dr_automation_recipient",
        authentication_type=AuthenticationType.DATABRICKS,
        data_recipient_global_metastore_id=local_metastore_id,
    )
except BadRequest:
    try:
        recipient = [
            r
            for r in w_source.recipients.list()
            if r.data_recipient_global_metastore_id == local_metastore_id
        ][0]
        print(f"Recipient with id {metastore_id} already exists. Skipping creation...")
    except IndexError:
        print(
            f"Recipient with id {metastore_id} does not exist in source workspace. Please validate the id and create it manually."
        )
        sys.exit()

# get all tables in the primary metastore
system_info = spark.sql("SELECT * FROM system.information_schema.tables")


# get remote provider name; it may or may not be the same as local_metastore_id
try:
    remote_provider_name = [
        p.name
        for p in w_target.providers.list()
        if p.data_provider_global_metastore_id == metastore_id
    ][0]
except IndexError:
    print(
        "Provider could not be found in target workspace; please check that it was created."
    )
    sys.exit()

# initalize df lists
cloned_table_names = []
cloned_table_schemas = []
cloned_table_catalogs = []
cloned_table_status = []
cloned_table_times = []

# iterate through all catalogs to share
catalog_list = [
    catalog
    for catalog in w_source.catalogs.list()
    if catalog.catalog_type == CatalogType.MANAGED_CATALOG
]


for cat in catalog_list:
    filtered_tables = [
        table
        for s in w_source.schemas.list(catalog_name=cat.name)
        for table in w_source.tables.list(catalog_name=cat.name, schema_name=s.name)
        if table.schema_name != "information_schema"
        and table.table_type == TableType.EXTERNAL
    ]

    unique_schemas = {table.schema_name for table in filtered_tables}

    all_tables = [table.name for table in filtered_tables]
    all_schemas = [table.schema_name for table in filtered_tables]

    # create the share for the current catalog and update permissions
    print(f"Creating share for catalog {cat.name}...")
    try:
        share = w_source.shares.create(name=f"{cat.name}_share")
        share_name = share.name
    except BadRequest:
        print(f"Share {cat.name}_share already exists. Skipping creation...")
        share_name = f"{cat.name}_share"

    try:
        _ = w_source.shares.update_permissions(
            share_name,
            changes=[
                PermissionsChange(add=[Privilege.SELECT], principal=recipient.name)
            ],
        )
    except BadRequest:
        print(f"Could not update permissions for share {share_name}.")

    # build update object with all schemas in the current catalog
    for schema in unique_schemas:
        print(f"{cat.name}.{schema}")
    updates = [
        SharedDataObjectUpdate(
            action=SharedDataObjectUpdateAction.ADD,
            data_object=SharedDataObject(
                name=f"{cat.name}.{schema}",
                data_object_type="SCHEMA",
                status=SharedDataObjectStatus.ACTIVE,
            ),
        )
        for schema in unique_schemas
    ]

    # update the share
    try:
        _ = w_source.shares.update(share_name, updates=updates)
    except Exception as e:
        print(f"Error updating share {share_name}: {e}")

    # create the shared catalog in the target workspace
    try:
        _ = w_target.catalogs.create(
            name=f"{cat.name}_share",
            provider_name=remote_provider_name,
            share_name=share_name,
        )
    except BadRequest:
        print(f"Shared catalog {cat.name}_share already exists. Skipping creation.")
    with ThreadPoolExecutor(max_workers=num_exec) as executor:
        threads = executor.map(
            clone_table,
            repeat(w_target),
            repeat(f"{cat.name}_share"),
            repeat(cat.name),
            all_schemas,
            all_tables,
            repeat(dr_warehouse_id),
        )

        for thread in threads:
            cloned_table_names.append(thread["table_name"])
            cloned_table_schemas.append(thread["schema"])
            cloned_table_catalogs.append(thread["catalog"])
            cloned_table_status.append(thread["status"])
            cloned_table_times.append(thread["creation_time"])

            if thread["status"] == "SUCCESS":
                print(
                    "Loaded table {}.{}.{}.".format(
                        thread["catalog"], thread["schema"], thread["table_name"]
                    )
                )

# create the table statuses as a df and write to a table in dr target
status_df = pd.DataFrame(
    {
        "catalog": cloned_table_catalogs,
        "schema": cloned_table_schemas,
        "table": cloned_table_names,
        "status": cloned_table_status,
        "sync_time": cloned_table_times,
    }
)
display(status_df)