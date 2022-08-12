terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
  }
}

provider "azurerm" {
  features {}
}


data "azurerm_subscription" "current" {
}

/*
Azure Subscription Data Module.
This module will return data about a specific Azure subscription.
*/
module "subscription" {
  source          = "git::https://github.com/Azure-Terraform/terraform-azurerm-subscription-data.git?ref=v1.0.0"
  subscription_id = data.azurerm_subscription.current.subscription_id
}

/*
Azure Naming Module.
This repository contains a list of variables and standards for naming resources in Microsoft Azure. It serves these primary purposes:

1. A central location for development teams to research and collaborate on allowed values and naming conventions.
2. A single source of truth for data values used in policy enforcement, billing, and naming.
3. A RESTful data source for application requiring information on approved values, variables and names.

This also show a great example of a github workflow that will deploy and run a RESTful API written in python.
*/
module "naming" {
  source = "git::https://github.com/Azure-Terraform/example-naming-template.git?ref=v1.0.0"
}

/*
Azure Metadata Module.
This module will return a map of mandatory tag for resources in Azure.

It is recommended that you always use this module to generate tags as it will prevent code duplication.
Also, it's reccommended to leverage this data as "metadata" to determine core details about resources in other modules.
*/
module "metadata" {
  source = "git::https://github.com/Azure-Terraform/terraform-azurerm-metadata.git?ref=v1.5.0"

  naming_rules = module.naming.yaml

  market              = "us"
  project             = "https://github.com/franknaw/azure-simple-app-service"
  location            = var.location
  environment         = "sandbox"
  product_name        = "appservice1"
  business_unit       = "infra"
  product_group       = "fnaw"
  subscription_id     = module.subscription.output.subscription_id
  subscription_type   = "dev"
  resource_group_type = "app"
}

/*
Azure Resource Group Module.
This module will create a new Resource Group in Azure.

Naming for this resource is as follows, based on published RBA naming convention.
*/
module "resource_group" {
  source = "git::https://github.com/Azure-Terraform/terraform-azurerm-resource-group.git?ref=v2.0.0"

  location = module.metadata.location
  names    = module.metadata.names
  tags     = module.metadata.tags
}

/*
Simple VNET Module.
*/
module "vnet" {
  source = "git::https://github.com/franknaw/azure-simple-network.git?ref=v1.0.0"

  resource_group_name      = module.resource_group.name
  location                 = module.resource_group.location
  product_name             = module.metadata.names.product_name
  tags                     = module.metadata.tags
  address_space            = ["10.12.0.0/22"]
  address_prefixes_private = ["10.12.0.0/24"]
  address_prefixes_public  = ["10.12.1.0/24"]
}

/*
Create a web app service plan.
An App Service plan defines a set of compute resources for a web app to run.
These compute resources are analogous to the server farm in conventional web hosting. 
One or more apps can be configured to run on the same computing resources (or in the same App Service plan).
*/
resource "azurerm_service_plan" "sp-node" {
  name                = "webapp-sp-node"
  location            = module.resource_group.rg.location
  resource_group_name = module.resource_group.rg.name
  os_type             = "Linux"
  sku_name            = "P1v2" #"F1" 
}

/*
Create a linux web app service.
Azure App Service is an HTTP-based (Paas) service for hosting web applications, REST APIs, and mobile back ends. 
The folowing languages are supported, .NET, .NET Core, Java, Ruby, Node.js, PHP, or Python. 
Applications run and scale on both Windows and Linux-based environments.
*/
resource "azurerm_linux_web_app" "web-app-node" {
  name                = var.web-app-name
  location            = module.resource_group.rg.location
  resource_group_name = module.resource_group.rg.name
  service_plan_id     = azurerm_service_plan.sp-node.id
  https_only          = true

  site_config {

    always_on           = false
    ftps_state = "Disabled"
    health_check_eviction_time_in_min = 10
    health_check_path = "/"
    http2_enabled = false
    ip_restriction = tolist([])
    load_balancing_mode = "LeastRequests"
    local_mysql_enabled = false
    managed_pipeline_mode = "Integrated"
    minimum_tls_version = "1.2"
    remote_debugging_enabled = false
    remote_debugging_version = "VS2019"
    scm_ip_restriction = tolist([])
    scm_minimum_tls_version = "1.2"
    scm_use_main_ip_restriction = false
    use_32_bit_worker = true
    vnet_route_all_enabled = false
    websockets_enabled = false
    worker_count = 1

    application_stack {
      node_version = "16-lts"
    }

  }

  logs {
    detailed_error_messages = true
    failed_request_tracing  = true
    application_logs {
      file_system_level = "Verbose"
    }
    http_logs {

      file_system {
        retention_in_mb   = 25
        retention_in_days = 1
      }

    }
  }
}

/*
Create a app service source control for the default production slot.
The linux web app service above creates the production slot by default.
This pulls the NodeJS HW app from a branch called production.
*/
resource "azurerm_app_service_source_control" "production-source" {
  app_id                 = azurerm_linux_web_app.web-app-node.id
  repo_url               = "https://github.com/franknaw/nodejs-hw"
  branch                 = "production"
  use_manual_integration = true
  use_mercurial          = false
}

/*
Create a linux web app slot for a staging instance
Slots are different environments exposed via a publicly available endpoint. 
One app instance is always mapped to the production slot, and you can swap instances assigned to a slot on demand.
*/

resource "azurerm_linux_web_app_slot" "slot-1" {
  name           = var.slot-1
  app_service_id = azurerm_linux_web_app.web-app-node.id
  https_only     = true

  site_config {
    minimum_tls_version = "1.2"
    always_on           = false
    application_stack {
      node_version = "16-lts"
    }

    health_check_eviction_time_in_min = 10
    health_check_path                 = "/"
  }

  logs {
    detailed_error_messages = true
    failed_request_tracing  = true
    application_logs {
      file_system_level = "Verbose"
    }
    http_logs {
      file_system {
        retention_in_mb   = 25
        retention_in_days = 1
      }
    }
  }
}

/*
Create a app service source control for the staging slot.
This pulls the NodeJS HW app from a branch called main.
*/
resource "azurerm_app_service_source_control_slot" "staging-source" {
  slot_id                = azurerm_linux_web_app_slot.slot-1.id
  repo_url               = "https://github.com/franknaw/nodejs-hw"
  branch                 = "main"
  use_manual_integration = true
  use_mercurial          = false
}

/*
This allows the app service to connect to GitHub via OAuth Token
*/
# resource "azurerm_source_control_token" "sc-token" {
#   type  = "GitHub"
#   token = "FRANKNAW2"
#   # token = "AZUREAPPSERVICE_PUBLISHPROFILE_B2DF17BDEDB84EBDB0A136CDEE0403B7"
# }
