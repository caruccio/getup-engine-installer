#########################################
###### Getup Database
#########################################

#variable "azure_database_capacity" {
#    default = 50
#}
#
#variable "azure_database_tier" {
#    default = "Basic"
#}
#
#locals {
#    database_username   = "getup"
#    api_database_name   = "getup"
#    usage_database_name = "usage"
#    azure_database_sku_name = {
#         "50" = "MYSQLB50"
#        "100" = "MYSQLB100"
#        "200" = "MYSQLS200"
#        "400" = "MYSQLS400"
#        "800" = "MYSQLS800"
#    }
#}
#
#resource "random_string" "mysql_admin_password" {
#    length = 16
#}
#
#resource "azurerm_mysql_server" "getup" {
#    name                        = "getupapi-${random_string.suffix.result}"
#    location                    = "${azurerm_resource_group.rg.location}"
#    resource_group_name         = "${azurerm_resource_group.rg.name}"
#    sku {
#        name        = "${lookup(local.azure_database_sku_name, var.azure_database_capacity)}"
#        capacity    = "${var.azure_database_capacity}"
#        tier        = "${var.azure_database_tier}"
#    }
#
#    administrator_login = "${local.database_username}"
#    administrator_login_password = "${random_string.mysql_admin_password.result}"
#    version = "5.7"
#    storage_mb = "128000"
#    ssl_enforcement = "Disabled"
#}
#
#resource "azurerm_mysql_database" "getup" {
#  name                = "${local.api_database_name}"
#  resource_group_name = "${azurerm_resource_group.rg.name}"
#  server_name         = "${azurerm_mysql_server.getup.name}"
#  charset             = "utf8"
#  collation           = "utf8_unicode_ci"
#}
#
#resource "azurerm_mysql_database" "usage" {
#  name                = "${local.usage_database_name}"
#  resource_group_name = "${azurerm_resource_group.rg.name}"
#  server_name         = "${azurerm_mysql_server.getup.name}"
#  charset             = "utf8"
#  collation           = "utf8_unicode_ci"
#}

#########################################
###### Getup API
#########################################

resource "azurerm_storage_account" "api" {
    name                        = "getupapi${random_string.suffix.result}"
    location                    = "${azurerm_resource_group.rg.location}"
    resource_group_name         = "${azurerm_resource_group.rg.name}"
    account_tier                = "Standard"
    account_replication_type    = "LRS"
}

resource "azurerm_storage_blob" "api" {
    name                    = "api"
    type                    = "block"
    resource_group_name     = "${azurerm_resource_group.rg.name}"
    storage_account_name    = "${azurerm_storage_account.api.name}"
    storage_container_name  = "${azurerm_storage_container.api.name}"
}

resource "azurerm_storage_container" "api" {
   name                     = "api"
   resource_group_name      = "${azurerm_resource_group.rg.name}"
   storage_account_name     = "${azurerm_storage_account.api.name}"
   container_access_type    = "container"
}

#########################################
###### Blob for Backup
#########################################

resource "azurerm_storage_account" "backup" {
    name                        = "getupbkp${random_string.suffix.result}"
    location                    = "${azurerm_resource_group.rg.location}"
    resource_group_name         = "${azurerm_resource_group.rg.name}"
    account_tier                = "Standard"
    account_replication_type    = "LRS"
}

resource "azurerm_storage_container" "backup" {
    name                    = "backup"
    resource_group_name     = "${azurerm_resource_group.rg.name}"
    storage_account_name    = "${azurerm_storage_account.backup.name}"
    container_access_type   = "private"
}

resource "azurerm_storage_blob" "backup" {
    name                    = "backup"
    type                    = "block"
    resource_group_name     = "${azurerm_resource_group.rg.name}"
    storage_account_name    = "${azurerm_storage_account.backup.name}"
    storage_container_name  = "${azurerm_storage_container.backup.name}"
}

#################################################################
## Outputs
#################################################################

# API
########

output "GETUPCLOUD_API_AZURE_STORAGE_ACCOUNT_NAME" {
    value = "${azurerm_storage_blob.api.storage_account_name}"
}

output "GETUPCLOUD_API_AZURE_STORAGE_CONTAINER_NAME" {
    value = "${azurerm_storage_container.api.name}"
}

output "GETUPCLOUD_API_AZURE_STORAGE_ACCOUNT_KEY" {
    value = "${azurerm_storage_account.api.primary_access_key}"
}

output "GETUPCLOUD_API_STORAGE_BACKEND" {
    value = "storages.backends.azure_storage.AzureStorage"
}

# Database
##########

output "GETUPCLOUD_DATABASE_MODE" {
    value = "hosted"
}

#output "GETUPCLOUD_DATABASE_HOSTNAME" {
#    value = "${azurerm_mysql_server.getup.fqdn}"
#}
#
#output "GETUPCLOUD_DATABASE_USERNAME" {
#    value = "${local.database_username}@${azurerm_mysql_server.getup.name}"
#}
#
#output "GETUPCLOUD_DATABASE_PASSWORD" {
#    value = "${random_string.mysql_admin_password.result}"
#}
#
#output "GETUPCLOUD_DATABASE_API_NAME" {
#    value = "${local.api_database_name}"
#}
#
#output "GETUPCLOUD_DATABASE_USAGE_NAME" {
#    value = "${local.usage_database_name}"
#}

# Backup
########

output "GETUPCLOUD_BACKUP_STORAGE_AZURE_ACCOUNT_NAME" {
    value = "${azurerm_storage_blob.backup.storage_account_name}"
}

output "GETUPCLOUD_BACKUP_STORAGE_AZURE_CONTAINER" {
    value = "${azurerm_storage_container.backup.name}"
}
output "GETUPCLOUD_BACKUP_STORAGE_AZURE_ACCOUNT_KEY" {
    value = "${azurerm_storage_account.backup.primary_access_key}"
}

output "GETUPCLOUD_BACKUP_STORAGE_KIND" {
    value = "blobstorage"
}
