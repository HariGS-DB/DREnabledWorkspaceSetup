# Databricks notebook source
from databricks.sdk import WorkspaceClient
import pandas as pd
from common import target_pat, target_host, source_pat, source_host


# create WorkspaceClient objects
w_source = WorkspaceClient(host=source_host, token=source_pat)
w_target = WorkspaceClient(host=target_host, token=target_pat)

# get source and target catalogs
source_catalogs = [x for x in w_source.catalogs.list()]
target_catalogs = [x for x in w_target.catalogs.list()]

for catalog in source_catalogs:
    source_schemas = [x for x in w_source.schemas.list(catalog.name)]
    target_schemas = [x for x in w_target.schemas.list(catalog.name)]
    source_schema_names = [x.name for x in source_schemas]
    target_schema_names = [x.name for x in target_schemas]
    schema_diff = list(set(source_schema_names) - set(target_schema_names))
    schemas_to_create = [x for x in source_schemas if x.name in schema_diff]

    for schema in schemas_to_create:
        schema_name = schema.name
        schema_comment = schema.comment
        schema_properties = schema.properties

        w_target.schemas.create(
            name=schema_name,
            comment=schema_comment,
            properties=schema_properties,
            catalog_name=catalog.name,
        )

        print(f"Created schema {catalog.name}.{schema_name}.")