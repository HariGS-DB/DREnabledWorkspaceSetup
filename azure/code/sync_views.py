# Databricks notebook source
import time
import pandas as pd
from itertools import repeat
from databricks.sdk import WorkspaceClient
from databricks.sdk.service import sql as dbsql
from concurrent.futures import ThreadPoolExecutor
from databricks.sdk.service.sql import Disposition
from databricks.sdk.service.sql import StatementState
from databricks.sdk.service.sql import CreateWarehouseRequestWarehouseType
from databricks.sdk.service.sql import ExecuteStatementRequestOnWaitTimeout
from databricks.sdk.service.catalog import TableType
from common import (
    target_pat,
    target_host,
    num_exec,
    response_backoff,
    source_pat,
    source_host,
    dr_warehouse_id,
)


# helper function to create a view
def create_view(w, catalog, schema, view_name, view_definition, warehouse):
    try:
        sqlstring = (
            f"CREATE OR REPLACE VIEW {catalog}.{schema}.{view_name} AS "
            f"{view_definition} "
        )

        resp = w.statement_execution.execute_statement(
            warehouse_id=warehouse,
            wait_timeout="0s",
            on_wait_timeout=ExecuteStatementRequestOnWaitTimeout("CONTINUE"),
            disposition=Disposition("EXTERNAL_LINKS"),
            statement=sqlstring,
        )

        while resp.status.state in {StatementState.PENDING, StatementState.RUNNING}:
            resp = w.statement_execution.get_statement(resp.statement_id)
            time.sleep(response_backoff)

        if resp.status.state != StatementState.SUCCEEDED:
            return {
                "catalog": catalog,
                "schema": schema,
                "view_name": view_name,
                "status": f"FAIL: {resp.status.error.message}",
                "creation_time": time.time_ns(),
            }
        return {
            "catalog": catalog,
            "schema": schema,
            "view_name": view_name,
            "status": "SUCCESS",
            "creation_time": time.time_ns(),
        }

    except Exception as e:
        return {
            "catalog": catalog,
            "schema": schema,
            "view_name": view_name,
            f"status": "FAIL: {e}",
            "creation_time": time.time_ns(),
        }


# create the WorkspaceClient pointed at the target WS
w_target = WorkspaceClient(host=target_host, token=target_pat)
w_source = WorkspaceClient(host=source_host, token=source_pat)


# initialize lists for status tracking
loaded_view_names = []
loaded_view_schemas = []
loaded_view_catalogs = []
loaded_view_status = []
loaded_view_times = []

# load all views per catalog
for cat in w_source.catalogs.list():
    filtered_views = [
        table
        for s in w_source.schemas.list(catalog_name=cat.name)
        for table in w_source.tables.list(catalog_name=cat.name, schema_name=s.name)
        if table.schema_name != "information_schema"
        and table.table_type == TableType.VIEW
    ]

    # get schemas and view names
    schemas = [view.schema_name for view in filtered_views]
    view_names = [view.name for view in filtered_views]
    view_definitions = [view.view_definition for view in filtered_views]

    with ThreadPoolExecutor(max_workers=num_exec) as executor:
        threads = executor.map(
            create_view,
            repeat(w_target),
            repeat(cat.name),
            schemas,
            view_names,
            view_definitions,
            repeat(dr_warehouse_id),
        )

        for thread in threads:
            loaded_view_names.append(thread["view_name"])
            loaded_view_schemas.append(thread["schema"])
            loaded_view_catalogs.append(thread["catalog"])
            loaded_view_status.append(thread["status"])
            loaded_view_times.append(thread["creation_time"])
            print(
                "Loaded view {}.{}.{}.".format(
                    thread["catalog"], thread["schema"], thread["view_name"]
                )
            )

# create the table statuses as a df and write to a table in dr target
status_df = pd.DataFrame(
    {
        "catalog": loaded_view_catalogs,
        "schema": loaded_view_schemas,
        "table": loaded_view_names,
        "status": loaded_view_status,
        "sync_time": loaded_view_times,
    }
)
display(status_df)

# COMMAND ----------

