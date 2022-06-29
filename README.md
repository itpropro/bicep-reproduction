## Reproduction repository for Azure bicep issues

Current issue:

**listKeys not idempotent**

Deployments use version 0.6.0 of the CARML library. As there are currently no public bicep registries with current versions of the CARML, it is copied under the current version subfolder to the `modules` folder.

### Create repro environment

To recreate the environment with Azure CLI, execute the following commands:

```PowerShell
az login # Login to your Azure environment
az subscription set -s [SUBSCRIPTION_ID] # Change to your desired target subscription for the deployment
az account show # Verify if on the correct subscription
cd X:\repos\bicep-reproduction # Cd into this repo
az deployment sub create -l 'westeurope' -n (New-Guid).Guid -f .\reproduction.bicep # Execute a deployment with Azure CLI and location westeurope
```

### Deprovisioning

Just delete all the created resource groups. They are created with "{PREFIX}-{ENVIRONMENT}".
If your environments are "prod" and "test" and you prefix is "testbicep" your resource groups will be:

- testbicep-dev
- testbicep-prod
