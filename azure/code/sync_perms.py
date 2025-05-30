# Databricks notebook source
# sync_perms.py
#
# Baseline script to sync permissions of tables, volumes, schemas and catalogs between two workspaces.
#
# NOTE: This script must be run in the PRIMARY workspace.
#
# This script will attempt to sync the permissions of all catalog, schema and table securables between a source and
# target workspace. All securables should already exist in the target workspace, i.e., this script assumes a metadata
# sync has already been performed. It will also only update permissions on objects that exist in the primary; i.e., if
# an object exists in the secondary but not the primary, no updates will be applied.
#
# Params that must be specified below:
#   -source_host: the hostname of the primary workspace.
#   -source_pat: an access token for the primary workspace; must be an ADMIN user.
#   -target_host: the hostname of the secondary workspace.
#   -target_pat: an access token for the secondary workspace; must be an ADMIN user.
#   -catalogs_to_copy: a list of the catalogs to be replicated between workspaces.
#   -num_exec: the number of threads to spawn in the ThreadPoolExecutor.

from itertools import repeat
from databricks.sdk.service import catalog
from databricks.sdk import WorkspaceClient
from concurrent.futures import ThreadPoolExecutor
from databricks.sdk.errors.platform import NotFound
from common import (target_pat, target_host,
                    source_pat, source_host,
                    num_exec)


# helper function to update object grants between source and target WS
def sync_grants(w_src, w_tgt, obj_name, obj_type):
    # get source and target grants
    source_grants = w_src.grants.get_effective(obj_type, obj_name)

    # if the object does not exist in the secondary workspace, we cannot fetch it
    try:
        target_grants = w_tgt.grants.get_effective(obj_type, obj_name)
    except NotFound:
        return {"name": obj_name, "status": "NotFound"}

    # get list of all distinct users with grants on the object
    user_list = {u.principal for u in source_grants.privilege_assignments}.union(
        {u.principal for u in target_grants.privilege_assignments})

    # create PermissionsChange object for each user where a change exists
    change_list = []
    for u in user_list:
        # get the source/target privileges; these may not exist in one or the other environment
        try:
            source_privs = [x.privilege for x in
                            [p.privileges for p in source_grants.privilege_assignments if p.principal == u][0]
                            if x.privilege is not None]
        except IndexError:
            source_privs = []

        try:
            target_privs = [x.privilege for x in
                            [p.privileges for p in target_grants.privilege_assignments if p.principal == u][0]
                            if x.privilege is not None]
        except IndexError:
            target_privs = []

        add_perms = list(set(source_privs) - set(target_privs))
        rem_perms = list(set(target_privs) - set(source_privs))

        # for the change list based on which types of changes exist
        if add_perms and rem_perms:
            change_list.append(catalog.PermissionsChange(
                add=add_perms,
                remove=rem_perms,
                principal=u))
        elif add_perms:
            change_list.append(catalog.PermissionsChange(
                add=add_perms,
                principal=u))
        elif rem_perms:
            change_list.append(catalog.PermissionsChange(
                remove=rem_perms,
                principal=u))

    # if any grants changed, update the object in target
    if change_list:
        w_tgt.grants.update(full_name=obj_name,
                            securable_type=obj_type,
                            changes=change_list)
        return {"name": obj_name, "status": "SUCCESS"}
    else:
        return {"name": obj_name, "status": None}


# create the WorkspaceClients for source and target workspaces
w_source = WorkspaceClient(host=source_host, token=source_pat)
w_target = WorkspaceClient(host=target_host, token=target_pat)

# get all tables in the source ws
table_info = spark.sql("SELECT * FROM system.information_schema.tables")
volume_info = spark.sql("SELECT * FROM system.information_schema.volumes")

# iterate through catalogs
for cat in w_source.catalogs.list():
    filtered_tables = [
        table
        for s in w_source.schemas.list(catalog_name=cat.name)
        for table in w_source.tables.list(catalog_name=cat.name, schema_name=s.name)
        if table.schema_name != "information_schema"
    ]
    filtered_volumes = [
        volume
        for s in w_source.schemas.list(catalog_name=cat.name)
        for volume in w_source.volumes.list(catalog_name=cat.name, schema_name=s.name)
    ]
    schemas = [schema for schema in w_source.schemas.list(catalog_name=cat.name)]


    # sync the catalog grants first
    res = sync_grants(w_source, w_target, cat.name, catalog.SecurableType.CATALOG)

    if res["status"] == "SUCCESS":
        print(f"Synced grants for catalog {cat.name}.")
    elif res["status"] == "NotFound":
        print(f"ERROR: catalog {cat.name} does not exist in target workspace. Sync metadata and re-run.")
    else:
        print(f"No changes to sync for catalog {cat.name}.")

    # get list of fully qualified schemas and tables
    schemas = [f"{cat.name}.{schema.name}" for schema in schemas]
    table_names = [f"{cat.name}.{schema}.{table}" for schema, table in
                   zip([table.schema_name for table in filtered_tables],
                       [table.name for table in filtered_tables])]
    volume_names = [f"{cat.name}.{schema}.{table}" for schema, table in
                    zip([volume.schema_name for volume in filtered_volumes],
                        [volume.name for volume in filtered_volumes])]

    # update schema grants in parallel
    with ThreadPoolExecutor(max_workers=num_exec) as executor:
        threads = executor.map(sync_grants,
                               repeat(w_source),
                               repeat(w_target),
                               schemas,
                               repeat(catalog.SecurableType.SCHEMA))

        for thread in threads:
            name = thread["name"]
            if thread["status"] == "SUCCESS":
                print(f"Synced grants for schema {name}.")
            elif thread["status"] == "NotFound":
                print(f"ERROR: schema {name} does not exist in target workspace. Sync metadata and re-run.")
            else:
                print(f"No changes to sync for schema {name}.")

    # update table grants in parallel
    with ThreadPoolExecutor(max_workers=num_exec) as executor:
        threads = executor.map(sync_grants,
                               repeat(w_source),
                               repeat(w_target),
                               table_names,
                               repeat(catalog.SecurableType.TABLE))

        for thread in threads:
            name = thread["name"]
            if thread["status"] == "SUCCESS":
                print(f"Synced grants for table {name}.")
            elif thread["status"] == "NotFound":
                print(f"ERROR: table {name} does not exist in target workspace. Sync metadata and re-run.")
            else:
                print(f"No changes to sync for table {name}.")

    # update volume grants in parallel
    with ThreadPoolExecutor(max_workers=num_exec) as executor:
        threads = executor.map(sync_grants,
                               repeat(w_source),
                               repeat(w_target),
                               volume_names,
                               repeat(catalog.SecurableType.VOLUME))

        for thread in threads:
            name = thread["name"]
            if thread["status"] == "SUCCESS":
                print(f"Synced grants for volume {name}.")
            elif thread["status"] == "NotFound":
                print(f"ERROR: volume {name} does not exist in target workspace. Sync volumes and re-run.")
            else:
                print(f"No changes to sync for volume {name}.")