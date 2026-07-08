# journal-app
solirius grad training

## Build Instructions
1) See "Generate Secrets" before proceeding
2) Run `./init-environment.sh` in your terminal to initialise Azure resources
3) Either push code to the repo to start deployment pipeline, or manually trigger `Main Deployment` under GitHub Actions

## Generate Secrets
The following secrets need to be generated and entered under the 'Terraform' environment
1) AZURE_CLIENT_ID
2) AZURE_CREDENTIALS
3) AZURE_SUBSCRIPTION_ID
4) AZURE_TENANT_ID

### Instructions for generating secrets
1) AZURE_SUBCSCRIPTION_ID, AZURE_TENANT_ID
    * Navigate to your terminal
    * `az login`
    * `az account show`
    * "id" is your AZURE_SUBSCRIPTION_ID
    * "tenantId" is your AZURE_TENANT_ID

---

2) AZURE_CLIENT_ID, AZURE_CREDENTIALS
    > `az ad sp create-for-rbac --name "journal-app" --role contributor --scopes /subscriptions/{subscription-id} --sdk-auth`
    * This will generate an App registration within Entra ID. Replace {subscription-id} with your own
    * "clientId" is your AZURE_CLIENT_ID
    * The entire contents of the JSON output is your AZURE_CREDENTIALS (including curly brackets)

---

3) OIDC Permissions
    * OIDC permissions need to be configured for GitHub actions to function correctly. 
    > `az ad app list --display-name "journal-app" --query "[0].appId" -o tsv`
    *  Take the output of this command, and replace <APP_ID> in the following command with it
    > `az ad app federated-credential create --id <APP_ID> --parameters '{ "name": "journal-app-trust", "issuer": "https://token.actions.githubusercontent.com", "subject": "repo:<ORG>/<REPO>:environment:Terraform", "description": "Trust GitHub Actions for main branch", "audiences": ["api://AzureADTokenExchange"] }'`
    * Replace <ORG> with the name of the owner of the GitHub repo, and <REPO> with the name of the GitHub repo.