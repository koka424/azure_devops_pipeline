terraform {
    required_version = ">= 0.11"
    backend "azurerm" {
        storage_account_name = "__terraformstorageaccount__"
        container_name       = "terraform"
        key                  = "terraform.tfstate"
        access_key  ="__storagekey__"
    }
}

provider "azurerm" {
    version = "=1.28.0"
}

resource "azurerm_resource_group" "test" {
    name        = "myTF_VSS_rg"
    location    = "eastus"
}

resource "azurerm_virtual_network" "test" {
    name            = "myTFVnet"
    address_space   = ["10.0.0.0/16"]
    location        = "eastus"
    resource_group_name = "${azurerm_resource_group.test.name}"
}

resource "azurerm_subnet" "frontend" {
    name                    = "frontend"
    resource_group_name     = "${azurerm_resource_group.test.name}"
    virtual_network_name    = "${azurerm_virtual_network.test.name}"
    address_prefix          = "10.0.1.0/24"
}

resource "azurerm_subnet" "backend" {
    name                    = "backend"
    resource_group_name     = "${azurerm_resource_group.test.name}"
    virtual_network_name    = "${azurerm_virtual_network.test.name}"
    address_prefix          = "10.0.2.0/24"
}

resource "azurerm_public_ip" "test" {
    name                = "example-pip"
    resource_group_name = "${azurerm_resource_group.test.name}"
    location            = "${azurerm_resource_group.test.location}"
    allocation_method   = "Dynamic"
}

locals {
  backend_address_pool_name      = "${azurerm_virtual_network.test.name}-beap"
  frontend_port_name             = "${azurerm_virtual_network.test.name}-feport"
  frontend_ip_configuration_name = "${azurerm_virtual_network.test.name}-feip"
  http_setting_name              = "${azurerm_virtual_network.test.name}-be-htst"
  listener_name                  = "${azurerm_virtual_network.test.name}-httplstn"
  request_routing_rule_name      = "${azurerm_virtual_network.test.name}-rqrt"
  redirect_configuration_name    = "${azurerm_virtual_network.test.name}-rdrcfg"
}

resource "azurerm_application_gateway" "network" {
    name            = "example-appgateway"
    resource_group_name = "${azurerm_resource_group.test.name}"
    location            = "${azurerm_resource_group.test.location}"

    sku {
        name        = "Standard_Small"
        tier        = "Standard"
        capacity    = 2
    }

    gateway_ip_configuration {
        name    = "my-gateway-ip-configuration"
        subnet_id = "${azurerm_subnet.frontend.id}"
    }

    frontend_port {
        name    = "${local.frontend_port_name}"
        port    = 80
    }

    frontend_ip_configuration {
        name                    = "${local.frontend_ip_configuration_name}"
        public_ip_address_id    = "${azurerm_public_ip.test.id}"
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
}

resource "azurerm_virtual_machine_scale_set" "vm" {
    name                    = "myTFVMSS-1"
    location                = "${azurerm_resource_group.test.location}"
    resource_group_name     = "${azurerm_resource_group.test.name}"
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
        name        = "Standard_DS1_v2"
        tier        = "Standard"
        capacity    = 2
    }

    storage_profile_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "16.04-LTS"
        version   = "latest"
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
            application_gateway_backend_address_pool_ids    = ["${azurerm_application_gateway.network.id}/backendAddressPools/${local.backend_address_pool_name}"]
        }
    }
}

resource "azurerm_public_ip" "jumpbox-ip" {
    name                = "jumpbox-pip"
    resource_group_name = "${azurerm_resource_group.test.name}"
    location            = "${azurerm_resource_group.test.location}"
    allocation_method   = "Dynamic"
}

resource "azurerm_network_security_group" "jumpbox-nsg" {
    name                = "SSH"
    location            = "eastus"
    resource_group_name = "${azurerm_resource_group.test.name}"

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
}

resource "azurerm_network_interface" "jumpbox-nic" {
    name                      = "myNIC"
    location                  = "eastus"
    resource_group_name       = "${azurerm_resource_group.test.name}"
    network_security_group_id = "${azurerm_network_security_group.jumpbox-nsg.id}"

    ip_configuration {
        name                          = "myNICConfg"
        subnet_id                     = "${azurerm_subnet.backend.id}"
        private_ip_address_allocation = "dynamic"
        public_ip_address_id          = "${azurerm_public_ip.jumpbox-ip.id}"
    }
}

resource "azurerm_virtual_machine" "jumpbox-vm" {
    name                  = "myTFVM"
    location              = "eastus"
    resource_group_name   = "${azurerm_resource_group.test.name}"
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

}