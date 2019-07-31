variable "component_vnet_name" {
    type    = "string"
    default = "${var.resource_group_name}-${var.location}-network"
}
resource "azurerm_virtual_network" "this" {
    name                = "${var.component_vnet_name}"
    resource_group_name = "${var.resource_group_name}"
    location            = "${var.location}"
    address_space       = "${var.vnet_address_space}"
}