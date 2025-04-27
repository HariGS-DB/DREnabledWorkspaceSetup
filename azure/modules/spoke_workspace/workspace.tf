data "databricks_node_type" "smallest" {
  local_disk = true
}

data "databricks_spark_version" "latest_lts" {
  long_term_support = true
}
#resource "databricks_cluster" "dr_cluster" {
#  count = var.dr ? 1 : 0
#  cluster_name            = "DRSyncCluster"
#  spark_version           = data.databricks_spark_version.latest_lts.id
#  node_type_id            = data.databricks_node_type.smallest.id
#  autotermination_minutes = 20
#  autoscale {
#    min_workers = 1
#    max_workers = 5
#    }
#}

resource "databricks_directory" "drnotebooks" {

  count = var.dr ? 1 : 0
  path = "/drnotebooks"
}


resource "databricks_notebook" "sync_managed_table" {
  count = var.dr ? 1 : 0
  source = "./code/sync_managed_tables.py"
  path   = "${databricks_directory.drnotebooks[0].path}/sync_managed_tables"
  depends_on = [databricks_directory.drnotebooks]
}
resource "databricks_notebook" "sync_external_tables" {
  count = var.dr ? 1 : 0
  source = "./code/sync_external_tables.py"
  path   = "${databricks_directory.drnotebooks[0].path}/sync_external_tables"
}
resource "databricks_notebook" "sync_ext_volumes" {
  count = var.dr ? 1 : 0
  source = "./code/sync_ext_volumes.py"
  path   = "${databricks_directory.drnotebooks[0].path}/sync_ext_volumes"
}
resource "databricks_notebook" "sync_schemas" {
  count = var.dr ? 1 : 0
  source = "./code/sync_schemas.py"
  path   = "${databricks_directory.drnotebooks[0].path}/sync_schemas"
}
resource "databricks_notebook" "sync_views" {
  count = var.dr ? 1 : 0
  source = "./code/sync_views.py"
  path   = "${databricks_directory.drnotebooks[0].path}/sync_views"
}
resource "databricks_notebook" "sync_perms" {
  count = var.dr ? 1 : 0
  source = "./code/sync_perms.py"
  path   = "${databricks_directory.drnotebooks[0].path}/sync_perms"
}

resource "databricks_job" "dr_sync_job" {
  count = var.dr ? 1 : 0
  name        = "Job to sync UC data and metadata"

  job_cluster {
    job_cluster_key = "dr_cluster"
    new_cluster {
      num_workers   = 4
      spark_version = data.databricks_spark_version.latest_lts.id
      node_type_id  = data.databricks_node_type.smallest.id
    }
  }

  task {
    task_key = "sync_schemas"

    job_cluster_key = "dr_cluster"

    notebook_task {
      notebook_path = databricks_notebook.sync_schemas[0].path
    }
  }

  task {
    task_key = "sync_managed_table"

    job_cluster_key = "dr_cluster"

    notebook_task {
      notebook_path = databricks_notebook.sync_managed_table[0].path
    }
    depends_on {
      task_key = "sync_schemas"
    }
  }

  task {
    task_key = "sync_external_tables"

    job_cluster_key = "dr_cluster"

    notebook_task {
      notebook_path = databricks_notebook.sync_external_tables[0].path
    }
    depends_on {
      task_key = "sync_managed_table"
    }
  }
  task {
    task_key = "sync_ext_volumes"

    job_cluster_key = "dr_cluster"

    notebook_task {
      notebook_path = databricks_notebook.sync_ext_volumes[0].path
    }
    depends_on {
      task_key = "sync_external_tables"
    }
  }
  task {
    task_key = "sync_views"

    job_cluster_key = "dr_cluster"

    notebook_task {
      notebook_path = databricks_notebook.sync_views[0].path
    }
    depends_on {
      task_key = "sync_ext_volumes"
    }
  }
  task {
    task_key = "sync_perms"

    job_cluster_key = "dr_cluster"

    notebook_task {
      notebook_path = databricks_notebook.sync_perms[0].path
    }
    depends_on {
      task_key = "sync_views"
    }
  }
}