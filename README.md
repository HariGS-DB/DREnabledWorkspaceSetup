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

### Code CICD



### Instruction to Deploy Infra

1. Open the Entra appliation created from the Azure Bot
2. Go to authentication and add Web redirect url as "https://token.botframework.com/.auth/web/redirect"
3. Go Expose an API:
* Click Add application URI and enter the uri in the format: "api://botid-<GeneratedID>"
* Add a scope:
    * name of scope "scope_as_user"
    * Who can consent: Admin and Users
    * Admin consent display name: "Teams can access User Profile"
    * Admin consent description: "Teams can access User Profile"
    * User consent display name: "Teams can access User Profile and make request on behalf of the User"
    * Click save
* Under authorized client application, click add application:
    * add 5e3ce6c0-2b1f-4285-8d4b-75ee78787346 (Teams web application) and select the created scope
    * add 1fec8e78-bce4-4aaf-ab1b-5451cc387264 (Teams desktop/mobile application) and select the created scope
4. Go to API permissions and add the following permissions:
* Azure Databricks -> User Impersonation
* Microsoft Graph  -> email, openid, offline_access, profile, User.Read


