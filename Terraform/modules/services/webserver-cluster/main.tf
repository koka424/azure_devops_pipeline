#terraform {
#    required_version = ">= 0.11"
#    backend "azurerm" {
#        storage_account_name = "${var.storage_account_name}"
#        container_name       = "terraform"
#        key                  = "terraform.tfstate"
#        access_key           = "${var.storage_account_key}"
#    }
#}

provider "azurerm" {
    version = "=1.28.0"
}

locals {
    resource_group                 = "${var.service}-${var.env}"
    vnet                           = "${local.resource_group}-${var.location}-network"
    frontend_subnet                = "${local.vnet}-subnet-frontend"
    backend_subnet                 = "${local.vnet}-subnet-backend"
    lb_public_ip                   = "${local.vnet}-lb-public-ip"
    application_gateway            = "${local.resource_group}-agw"
    vmss                           = "${local.resource_group}-vmss"
    backend_address_pool_name      = "${local.vnet}-beap"
    frontend_port_name             = "${local.vnet}-feport"
    frontend_ip_configuration_name = "${local.vnet}-feip"
    http_setting_name              = "${local.vnet}-be-htst"
    listener_name                  = "${local.vnet}-httplstn"
    request_routing_rule_name      = "${local.vnet}-rqrt"
    redirect_configuration_name    = "${local.vnet}-rdrcfg"
    common_tags                    = {
        env      = "${var.env}"
        app      = "${var.app}"
        service  = "${var.service}"
        location = "${var.location}"
    }
}

resource "azurerm_resource_group" "this" {
    name        = "${local.resource_group}"
    location    = "${var.location}"

    tags        = "${local.common_tags}"
}

resource "azurerm_virtual_network" "this" {
    name                = "${local.vnet}"
    resource_group_name = "${local.resource_group}"
    location            = "${var.location}"
    address_space       = "${var.vnet_address_space}"

    tags                = "${local.common_tags}"
}

resource "azurerm_subnet" "frontend" {
    name                    = "${local.frontend_subnet}"
    resource_group_name     = "${local.resource_group}"
    address_prefix          = "${var.frontend_subnet_prefix}"
    virtual_network_name    = "${local.vnet}"
}

resource "azurerm_subnet" "backend" {
    name                    = "${local.backend_subnet}"
    resource_group_name     = "${local.resource_group}"
    address_prefix          = "${var.backend_subnet_prefix}"
    virtual_network_name    = "${local.vnet}"
}

resource "azurerm_public_ip" "lb" {
    name                = "${local.lb_public_ip}"
    resource_group_name = "${local.resource_group}"
    location            = "${var.location}"
    allocation_method   = "Dynamic"

    tags                = "${local.common_tags}"
}

resource "azurerm_application_gateway" "this" {
    name                = "${local.application_gateway}"
    resource_group_name = "${local.resource_group}"
    location            = "${var.location}"

    sku {
        name     = "${var.application_gateway_sku.name}"
        tier     = "${var.application_gateway_sku.tier}"
        capacity = "${var.application_gateway_sku.capacity}"
    }

    gateway_ip_configuration {
        name    = "${local.application_gateway}-gw-ip-cfg"
        subnet_id = "${azurerm_subnet.frontend.id}"
    }

    frontend_port {
        name    = "${local.frontend_port_name}"
        port    = 80
    }

    frontend_ip_configuration {
        name                    = "${local.frontend_ip_configuration_name}"
        public_ip_address_id    = "${azurerm_public_ip.lb.id}"
    }

    backend_address_pool {
        name = "${local.backend_address_pool_name}"
    }

    backend_http_settings {
        name                    = "${local.http_setting_name}"
        cookie_based_affinity   = "Disabled"
        path                    = "/"
        port                    = 80
        protocol                = "Http"
        request_timeout         = 1
    }

    http_listener {
        name                            = "${local.listener_name}"
        frontend_ip_configuration_name  = "${local.frontend_ip_configuration_name}"
        frontend_port_name              = "${local.frontend_port_name}"
        protocol                        = "Http"
    }

    request_routing_rule {
        name                        = "${local.request_routing_rule_name}"
        rule_type                   = "Basic"
        http_listener_name          = "${local.listener_name}"
        backend_address_pool_name   = "${local.backend_address_pool_name}"
        backend_http_settings_name  = "${local.http_setting_name}"
    }

    tags                = "${local.common_tags}"
}

resource "azurerm_virtual_machine_scale_set" "this" {
    name                    = "${local.vmss}"
    location                = "${var.location}"
    resource_group_name     = "${local.resource_group}"
    upgrade_policy_mode     = "Manual"

    extension {
        auto_upgrade_minor_version = true
        name                       = "CustomScript"
        provision_after_extensions = []
        publisher                  = "Microsoft.Azure.Extensions"
        settings                   = jsonencode(
            {
                commandToExecute = "./install_nginx.sh"
                fileUris         = [
                    "https://raw.githubusercontent.com/Azure/azure-docs-powershell-samples/master/application-gateway/iis/install_nginx.sh",
                ]
            }
        )
        type                       = "CustomScript"
        type_handler_version       = "2.0"
    }

    sku {
        name     = "${var.vmss_sku.name}"
        tier     = "${var.vmss_sku.tier}"
        capacity = "${var.vmss_sku.capacity}"
    }

    storage_profile_image_reference {
        publisher = "${var.vmss_storage_profile_image_reference.publisher}"
        offer     = "${var.vmss_storage_profile_image_reference.offer}"
        sku       = "${var.vmss_storage_profile_image_reference.sku}"
        version   = "${var.vmss_storage_profile_image_reference.version}"

    }

    storage_profile_os_disk {
        name              = ""
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Premium_LRS"
    }

    storage_profile_data_disk {
        lun             = 0
        caching         = "ReadWrite"
        create_option   = "Empty"
        disk_size_gb    = 10
    }

    os_profile {
        computer_name_prefix    = "myTFVM"
        admin_username          = "plankton"
        admin_password          = "Password1234!"
    }

    os_profile_linux_config {
        disable_password_authentication = false
    }

    network_profile {
        name    = "terraformnetworkprofile"
        primary = true

        ip_configuration {
            name                                            = "TestIPConfiguration"
            primary                                         = true
            subnet_id                                       = "${azurerm_subnet.backend.id}"
            application_gateway_backend_address_pool_ids    = ["${azurerm_application_gateway.this.id}/backendAddressPools/${local.backend_address_pool_name}"]
        }
    }

    tags                = "${merge(
                                local.common_tags,
                                {
                                    tier      = "web"
                                    webserver = "wildfly"
                                })
                            }"
}

resource "azurerm_public_ip" "jumpbox-ip" {
    name                = "jumpbox-pip"
    resource_group_name = "${local.resource_group}"
    location            = "${var.location}"
    allocation_method   = "Dynamic"

    tags                = "${local.common_tags}"
}

resource "azurerm_network_security_group" "jumpbox-nsg" {
    name                = "SSH"
    resource_group_name = "${local.resource_group}"
    location            = "${var.location}"

    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    tags                = "${local.common_tags}"
}

resource "azurerm_network_interface" "jumpbox-nic" {
    name                      = "myNIC"
    resource_group_name       = "${local.resource_group}"
    location                  = "${var.location}"
    network_security_group_id = "${azurerm_network_security_group.jumpbox-nsg.id}"

    ip_configuration {
        name                          = "myNICConfg"
        subnet_id                     = "${azurerm_subnet.backend.id}"
        private_ip_address_allocation = "dynamic"
        public_ip_address_id          = "${azurerm_public_ip.jumpbox-ip.id}"
    }

    tags                = "${local.common_tags}"
}

resource "azurerm_virtual_machine" "jumpbox-vm" {
    name                  = "myTFVM"
    resource_group_name   = "${local.resource_group}"
    location              = "${var.location}"
    network_interface_ids = ["${azurerm_network_interface.jumpbox-nic.id}"]
    vm_size               = "Standard_DS1_v2"

    storage_os_disk {
        name              = "myOsDisk"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Premium_LRS"
    }

    storage_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "16.04-LTS"
        version   = "latest"
    }

    os_profile {
        computer_name  = "myTFVM"
        admin_username = "plankton"
        admin_password = "Password1234!"
    }

    os_profile_linux_config {
        disable_password_authentication = false
    }

    tags                = "${local.common_tags}"
}