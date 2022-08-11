### A proof of concept showing Azure App Service
* Please see [main.tf](./main.tf) for more details about the app service resources.

***
#### Notes
TF_LOG=debug terraform apply -var-file="poc.tfvars"
az webapp list-runtimes --linux

