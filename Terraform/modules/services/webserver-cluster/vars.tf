#
# Project Variables
variable "env" {
    description = "The environment the deployment belongs to."
    type        = string
}

variable "app" {
    description = "The application the deployment is part of."
    type        = string
}

variable "service" {
    description = "The name of the service or application to be deployed."
    type        = string
}

variable "location" {
    description = "The location/region where the virtual network is created. Changing this forces a new resource to be created."
    default     = "eastus"
}

#
# Network Variables

variable "vnet_address_space" {
    description = "The address space of the VNET to use for this deployment."
    type        = list
}

variable "frontend_subnet_prefix" {
    description = "The address prefix of the frontend subnet."
    type        = string
}

variable "backend_subnet_prefix" {
    description = "The address prefix of the backend subnet."
    type        = string
}

#
# Application Gateway Variables

variable "application_gateway_sku" {
    description = "A hash defining the name, tier, and capacity of the SKU."
    default     = {
        name     = "Standard_Small"
        tier     = "Standard"
        capacity = 2
    }
}

#
# VMSS Variables

variable "vmss_sku" {
    description = "A hash defining the name, tier, and capacity of the SKU."
    default = {
        name     = "Standard_B1s"
        tier     = "Standard"
        capacity = 2
    }
}

variable "vmss_storage_profile_image_reference" {
    description = "A hash defining the name, offer, sku, and version of the image for the VMSS."
    default = {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "16.04-LTS"
        version   = "latest"
    }
}