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
    ExternalLocationInfo,
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


def get_target_location(
    source_ext_locations: [ExternalLocationInfo],
    target_ext_locations: dict,
    source_table_location,
):
    for location in source_ext_locations:
        if source_table_location.startswith(location.url):
            path_suffix = source_table_location.replace(location.url, "")
            print(path_suffix)
            return f"{target_ext_locations[location.name]}{path_suffix}"


# helper function to clone a table from one catalog to another


def clone_table(
    w: WorkspaceClient,
    source_catalog,
    target_catalog,
    schema,
    table_name,
    source_table_location,
    target_table_location,
    warehouse,
):
    print(f"Cloning table {source_catalog}.{schema}.{table_name}...")
    try:
        sqlstring = (
            f"CREATE OR REPLACE TABLE {target_catalog}.{schema}.{table_name} "
            f"DEEP CLONE delta.`{source_table_location}` "
            f"LOCATION '{target_table_location}'"
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


# get all tables in the primary metastore


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
source_ext_locations = [location for location in w_source.external_locations.list()]
target_ext_locations = {
    location.name: location.url for location in w_target.external_locations.list()
}


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

    source_table_locs = [table.storage_location for table in filtered_tables]
    target_table_locs = [
        get_target_location(source_ext_locations, target_ext_locations, loc)
        for loc in source_table_locs
    ]

    with ThreadPoolExecutor(max_workers=num_exec) as executor:
        threads = executor.map(
            clone_table,
            repeat(w_target),
            repeat(f"{cat.name}_share"),
            repeat(cat.name),
            all_schemas,
            all_tables,
            source_table_locs,
            target_table_locs,
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

# COMMAND ----------

