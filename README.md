# DREnabledWorkspaceSetup

## Objective

This repo helps in setting up a Databricks workspace for Disaster Recovery readiness. It contains code to deploy a secure Databricks workspace
in a Active Passive mode on azure cloud across two regions. It Also contains code which are deployed to run and sync the data between the two region

## Architecture Diagram
![Azure DR Setup.png](images%2FAzure%20DR%20Setup.png)

## Key Features

- Deploys a Hub and Spoke set up on both primary and secondary region
- Creates a secure workspace deployment with
  - front-end and back-end private link
  - firewall for exfiltration protection
  - PE connection between classic and serverless compute to storage
  - CMK for managed storage and service encryption using Key Vault
- Create multiple spoke workspaces to one hub in both primary and secondary
- Creates workspace catalog per workspace
- Deploys a workflow in secondary to do UC data and metadata replication


## Data Replication Job

The data replication job gets deployed as part of the infra deployment. The job is deployed in the secondary workspace and syncs
data from primary to secondary workspace.
Two storage account is created in each workspace
 - uc storage: This storage account contains two containers, one for uc managed catalog location and another for external 
delta table location. The data in this storage is replicated using deep clone, and underlying cloud replication is not used
 - external storage: This storage account contains container to store external non delta table and external volume.
This storage account is enabled with GRS to replicate the data using cloud services.

The replication job consists of the following tasks:
- sync schemas between primary and secondary
- run deep clone using shared sync for managed table from primary to secondary
- run deep clone for external delta table
- sync views from primary to secondary
- create external volumes from primary to secondary
- sync UC permissions from primary to secondary using the information schema system tables

## Infra CICD

The CICD process is implemented using two github actions:
 - infra_push.yml: This action is triggered on PR submission to main branch and runs terraform fmt, validate, init and plan
 - infra_release.yml: This action is triggered on PR merge following approval. This ensures the infra is deployed in 
both primary and secondary region. It uses github environment variables to determin the right region setup.
 - The end to end infra is deployed using a service principal which has permission on two regions within a subscription

The high level flow of terraform infra CICD is shown below

![tfcicd.png](images%2Ftfcicd.png)

### Code CICD

In addition to infra, the repo also contains example to deploy code using Databricks asset bundles and CICD.

The CICD process is implemented using two github actions:
- code_push.yml: This action is triggered on PR submission to main branch and runs pytest to perform unit tests and deploys the code in test 
environment using databricks bundle deploy --target test
- code_release.yml: This action is triggered on PR merge following approval. This ensures the code is deployed in
  both primary and secondary region. It uses github environment variables to determine the right region setup. It deploys the 
  code using databricks bundle deploy --target prod(and dr for secondary)

The high level flow of code CICD using dabs is shown below

![codecicd.png](images%2Fcodecicd.png)

### Instruction to Deploy Infra

1. Open terraform.tfvars and edit the following
   - databricks_account_id: databricks account id
   - hub_vnet_cidr: cidr of hub vnet
   - tags: to be applied on the resources
   - subscription_id: subscription id of the azure tenant
    
2. Use github settings to create two environment (prod and dr) and store the following
   - TF_VAR_HUB_RESOURCE_SUFFIX: resource suffix for each environment
   - TF_VAR_LOCATION: infra deployment azure region
   - TF_VAR_SPOKE_CONFIG: spoke config (sample value in terraform.tfvars)
   - TF_VAR_DR: flag to set if its dr oor not (false in prod and true in dr)
   - BACKEND_CONTAINER_NAME: seperate container name to store the tf state file for both primary and secondary region
3. In addition also create github variables for following:
   - AZURE_AD_CLIENT_ID
   - AZURE_AD_TENANT_ID
   - AZURE_SUBSCRIPTION_ID
   - BACKEND_RG_NAME
   - BACKEND_SA_NAME
   - BACKEND_KEY
4. Create a secret to store the service principal secret