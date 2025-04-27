# Databricks notebook source
from itertools import repeat
from databricks.sdk import WorkspaceClient
from databricks.sdk.service import catalog
from concurrent.futures import ThreadPoolExecutor
from databricks.sdk.errors.platform import ResourceAlreadyExists
from common import target_pat, target_host, source_pat, source_host, num_exec
from databricks.sdk.service.catalog import VolumeType, VolumeInfo


# helper function to create volumes and set appropriate owner
def create_volume(w, catalog_name, schema_name, volume_name, location, owner):
    print(f"Creating volume {volume_name} in {catalog_name}.{schema_name}...")

    # try creating new volume
    try:
        volume = w.volumes.create(
            catalog_name=catalog_name,
            schema_name=schema_name,
            name=volume_name,
            storage_location=location,
            volume_type=catalog.VolumeType.EXTERNAL,
        )

        _ = w.volumes.update(name=volume.full_name, owner=owner)
        return {"volume": volume.full_name, "status": "success"}

    # if volume already exists, just update the owner (in case it has changed)
    except ResourceAlreadyExists:
        _ = w.volumes.update(
            name=f"{catalog_name}.{schema_name}.{volume_name}", owner=owner
        )
        return {
            "volume": f"{catalog_name}.{schema_name}.{volume_name}",
            "status": "already_exists",
        }

    # for any other exception, return the error
    except Exception as e:
        return {
            "volume": f"{catalog_name}.{schema_name}.{volume_name}",
            "status": f"ERROR: {e}",
        }


# create the WorkspaceClient pointed at the target WS
w_target = WorkspaceClient(host=target_host, token=target_pat)
w_source = WorkspaceClient(host=source_host, token=source_pat)

# pull system tables from source ws
system_info = spark.sql("SELECT * FROM system.information_schema.volumes")

# loop through all catalogs to copy, then copy all volumes in these catalogs.
#
# note: we avoid listing volumes and doing a comparison since this would likely be slower than just looping through all
# volumes and dealing with the "already_exists" errors. We attempt to update owners in case the volume already exists
# but the owner has changed.

for cat in w_source.catalogs.list():
    filtered_volumes = [
        volume
        for s in w_source.schemas.list(catalog_name=cat.name)
        for volume in w_source.volumes.list(catalog_name=cat.name, schema_name=s.name)
        if volume.volume_type == VolumeType.EXTERNAL
    ]

    # get schemas, tables and locations in list form
    schema_names = [volume.schema_name for volume in filtered_volumes]
    volume_names = [volume.name for volume in filtered_volumes]
    volume_locs = [volume.storage_location for volume in filtered_volumes]
    volume_owners = [volume.owner for volume in filtered_volumes]
    catalog_names = [volume.catalog_name for volume in filtered_volumes]

    with ThreadPoolExecutor(max_workers=num_exec) as executor:
        threads = executor.map(
            create_volume,
            repeat(w_target),
            catalog_names,
            schema_names,
            volume_names,
            volume_locs,
            volume_owners,
        )

        for thread in threads:
            if thread["status"] == "success":
                print("Created volume {}.".format(thread["volume"]))
            elif thread["status"] == "already_exists":
                print(
                    "Skipped volume {} because it already exists.".format(
                        thread["volume"]
                    )
                )
            else:
                print(
                    "Could not create volume {}; error: {}".format(
                        thread["volume"], thread["status"]
                    )
                )