#########################################
###### Provider
#########################################

provider "azurerm" {
    subscription_id = "${var.azure_subscription_id}"
    version         = "1.1.2"
#    client_id       = "${var.azure_client_id}"
#    client_secret   = "${var.azure_client_secret}"
#    tenant_id       = "${var.azure_tenant_id}"
}

#variable "azure_client_id" {
#   type        = "string"
#   description = "Azure Client ID"
#}
#
#variable "azure_client_secret" {
#   type        = "string"
#   description = "Azure Client Secret"
#}
#
#variable "azure_tenant_id" {
#    type        = "string"
#    description = "Azure Tenant ID"
#}

variable "azure_subscription_id" {
    type        = "string"
    description = "Azure Subscription ID"
}

variable "azure_location" {
    type        = "string"
    description = "Azure location for deployment"
}

variable "azure_resource_group" {
    type        = "string"
    description = "Azure resource group"
}

variable "user" {
    type    = "string"
    default = "centos"
    description = "Username for login"
}

variable "os" {
    type = "string"
    default = "centos"
}

variable "os_offers" {
    type    = "map"
    default = {
        centos.publisher = "OpenLogic"
        centos.offer     = "CentOS"
        centos.sku       = "7.4"
        centos.version   = "latest"

        rhel.publisher   = "RedHat"
        rhel.offer       = "RHEL"
        rhel.sku         = "7-RAW"
        rhel.version     = "latest"
    }
}

variable "user_private_key_file" {
    type    = "string"
    description = "SSH Private key content (not file)"
}

variable "user_public_key_file" {
  type        = "string"
  description = "SSH Public key content (not file)"
}

#########################################
###### Common Resources
#########################################

resource "random_string" "suffix" {
    length = 6
    upper = false
    special = false
}

data "azurerm_resource_group" "rg" {
  name = "${var.azure_resource_group}"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-${random_string.suffix.result}"
  address_space       = ["10.0.0.0/8"]
  location            = "${data.azurerm_resource_group.rg.location}"
  resource_group_name = "${data.azurerm_resource_group.rg.name}"
}

resource "azurerm_subnet" "snet" {
  name                      = "snet-${random_string.suffix.result}"
  resource_group_name       = "${data.azurerm_resource_group.rg.name}"
  virtual_network_name      = "${azurerm_virtual_network.vnet.name}"
  network_security_group_id = "${azurerm_network_security_group.ssh.id}"
  address_prefix            = "10.10.0.0/16"
}

resource "azurerm_network_security_group" "ssh" {
  name                = "ssh-${random_string.suffix.result}"
  location            = "${data.azurerm_resource_group.rg.location}"
  resource_group_name = "${data.azurerm_resource_group.rg.name}"

  security_rule {
    name                       = "allowSSHin_all"
    description                = "Allow SSH in from all locations"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

#########################################
###### Bastion
#########################################

resource "azurerm_public_ip" "bastion-image" {
  name                          = "bastion-image-${random_string.suffix.result}"
  resource_group_name           = "${data.azurerm_resource_group.rg.name}"
  location                      = "${data.azurerm_resource_group.rg.location}"
  public_ip_address_allocation  = "static"
  domain_name_label             = "bastion-image-${lower(data.azurerm_resource_group.rg.name)}-${random_string.suffix.result}"
  depends_on                    = [ "azurerm_subnet.snet", "azurerm_network_security_group.ssh"]
}

resource "azurerm_network_interface" "bastion" {
  name                      = "bastion-${random_string.suffix.result}"
  location                  = "${data.azurerm_resource_group.rg.location}"
  resource_group_name       = "${data.azurerm_resource_group.rg.name}"
  network_security_group_id = "${azurerm_network_security_group.ssh.id}"
  depends_on                = ["azurerm_public_ip.bastion-image"]

  ip_configuration {
    name                          = "bastion"
    subnet_id                     = "${azurerm_subnet.snet.id}"
    private_ip_address_allocation = "dynamic"
    public_ip_address_id          = "${azurerm_public_ip.bastion-image.id}"
  }
}

resource "azurerm_virtual_machine" "bastion" {
    name                  = "bastion-${random_string.suffix.result}"
    location              = "${data.azurerm_resource_group.rg.location}"
    resource_group_name   = "${data.azurerm_resource_group.rg.name}"
    network_interface_ids = ["${azurerm_network_interface.bastion.id}"]
    vm_size               = "Standard_DS2_v2"

    delete_os_disk_on_termination = true
    delete_data_disks_on_termination = true

    storage_image_reference {
        publisher   = "${lookup(var.os_offers, "${var.os}.publisher")}"
        offer       = "${lookup(var.os_offers, "${var.os}.offer")}"
        sku         = "${lookup(var.os_offers, "${var.os}.sku")}"
        version     = "${lookup(var.os_offers, "${var.os}.version")}"
    }

    storage_os_disk {
        name              = "bastion-osdisk-${random_string.suffix.result}"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Standard_LRS"
    }

    os_profile {
        computer_name  = "bastion"
        admin_username = "${var.user}"
    }

    os_profile_linux_config {
        disable_password_authentication = true

        ssh_keys {
            path     = "/home/${var.user}/.ssh/authorized_keys"
            key_data = "${file("${var.user_public_key_file}")}"
        }
    }

    connection {
        type         = "ssh"
        host         = "${azurerm_public_ip.bastion-image.ip_address}"
        user         = "${var.user}"
        private_key  = "${file("${var.user_private_key_file}")}"
        agent        = false
    }

    provisioner "remote-exec" {
        inline = [
            "sudo -EH yum update -y",
            "sudo -EH yum install nc -y",
            "sudo -EH /usr/sbin/waagent -force -deprovision+user && export HISTSIZE=0 && sync"
        ]
    }
}

#########################################
###### Nodes
#########################################

resource "azurerm_public_ip" "node-image" {
  name                          = "node-image-${random_string.suffix.result}"
  resource_group_name           = "${data.azurerm_resource_group.rg.name}"
  location                      = "${data.azurerm_resource_group.rg.location}"
  public_ip_address_allocation  = "static"
  domain_name_label             = "node-image-${lower(data.azurerm_resource_group.rg.name)}-${random_string.suffix.result}"
  depends_on                    = [ "azurerm_subnet.snet", "azurerm_network_security_group.ssh"]
}

resource "azurerm_network_interface" "node" {
  name                      = "node-${random_string.suffix.result}"
  location                  = "${data.azurerm_resource_group.rg.location}"
  resource_group_name       = "${data.azurerm_resource_group.rg.name}"
  network_security_group_id = "${azurerm_network_security_group.ssh.id}"

  ip_configuration {
    name                          = "node-${random_string.suffix.result}"
    subnet_id                     = "${azurerm_subnet.snet.id}"
    private_ip_address_allocation = "dynamic"
    public_ip_address_id          = "${azurerm_public_ip.node-image.id}"
  }
}

resource "azurerm_virtual_machine" "node" {
    name                  = "node-${random_string.suffix.result}"
    location              = "${data.azurerm_resource_group.rg.location}"
    resource_group_name   = "${data.azurerm_resource_group.rg.name}"
    network_interface_ids = ["${azurerm_network_interface.node.id}"]
    vm_size               = "Standard_DS2_v2"

    delete_os_disk_on_termination = true
    delete_data_disks_on_termination = true

    storage_image_reference {
        publisher   = "${lookup(var.os_offers, "${var.os}.publisher")}"
        offer       = "${lookup(var.os_offers, "${var.os}.offer")}"
        sku         = "${lookup(var.os_offers, "${var.os}.sku")}"
        version     = "${lookup(var.os_offers, "${var.os}.version")}"
    }

    storage_os_disk {
        name              = "node-osdisk-${random_string.suffix.result}"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Standard_LRS"
    }

    storage_data_disk {
        name              = "node-datadisk-container-${random_string.suffix.result}"
        managed_disk_type = "Standard_LRS"
        create_option     = "Empty"
        lun               = 0
        disk_size_gb      = "100"
    }


    storage_data_disk {
        name              = "node-datadisk-docker-${random_string.suffix.result}"
        managed_disk_type = "Standard_LRS"
        create_option     = "Empty"
        lun               = 1
        disk_size_gb      = "200"
    }

    os_profile {
        computer_name  = "node"
        admin_username = "${var.user}"
    }

    os_profile_linux_config {
        disable_password_authentication = true

        ssh_keys {
            path     = "/home/${var.user}/.ssh/authorized_keys"
            key_data = "${file("${var.user_public_key_file}")}"
        }
    }

    connection {
        type         = "ssh"
        host         = "${azurerm_public_ip.node-image.ip_address}"
        user         = "${var.user}"
        private_key  = "${file("${var.user_private_key_file}")}"
        agent        = false
    }

    provisioner "file" {
        source      = "provision.sh"
        destination = "/tmp/provision.sh"
    }

    provisioner "remote-exec" {
        inline = [
            "chmod +x /tmp/provision.sh",
            "sudo -EH bash -c /tmp/provision.sh",
            "sudo -EH /usr/sbin/waagent -force -deprovision+user && export HISTSIZE=0 && sync"
        ]
    }
}

output "SUFFIX" {
    value = "${random_string.suffix.result}"
}
