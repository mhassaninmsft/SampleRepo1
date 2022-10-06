# Terraform Scaffolding

## Introduction

This repo contains a fully working project structure that deploys a terraform project along with a C# Azure function.
The repo also contains the CI/CD pipeline to

1. deploy the code into 3 enviiornments (dev -> test -> prod)
2. deploy the Azure function code automatically to Azure on successfull build and test and after the PR merges
3. When there is a terraform change on a PR, it evaulates the pkan and writes a comment on the PR for reviewers to see planned changes
4. Has an end to end battery of tests that runs on each PR
5. Utilizes github environments to facilitate deploymnet into the 3 stages of pipelines (dev -> test -> prod)

## Quick start

This repo is a skeleton for you to start your project that uses Azure and Terraform to manage the infrastructure, to start:

1. Clone this repo.
2. In your cloned github repo, modify the following parameters with a service principal that has permission to deploy your infrastrucure
   ```text

  ARM_CLIENT_ID: 'e54c489c-92a4-4b25-a005-1710958dda46'
  ARM_CLIENT_SECRET: ${{ secrets.ARM_CLIENT_SECRET }}
  ARM_SUBSCRIPTION_ID: 'ec18dca1-0751-4307-bbac-6150896ac498'
  ARM_TENANT_ID: '72f988bf-86f1-41af-91ab-2d7cd011db47'

   ```text

3. Add a secret in github secrets
4. Create 3 environments in github as described here
5. For each environment add 2 secrets
a.BACKEND_TFVARS which contains the backend configuration required for the app. An example Backend TFVARS file is shown below
``` text
storage_account_name = "mystorageaccount"
container_name = "terraform"
key = "local123.tfstate"
resource_group_name = "rg_resources_name"
subscription_id = "SUBSCRIPTION_ID"
tenant_id = "TENANT_ID"

```
b. set the Azure function publish