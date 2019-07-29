# Outputs that are unable to be gathered during the planning phase need to be ommitted.
# This setup allows us to do that. You have to define the "enable_output" var in the 'main.tf'
# root.

variable "enable_output" {
    type = bool
}

data "azurerm_public_ip" "lb" {
    count               = "${var.enable_output == false ? 0 : 1 }"
    name                = "${local.lb_public_ip}"
    resource_group_name = "${local.resource_group}"
}

output "public_ip_lb" {
    value = "${ var.enable_output == false ? "" : data.azurerm_public_ip.lb.0.ip_address }"
}

data "null_data_source" "value" {
    inputs = {
        var = var.enable_output == false ? "" : true
    }
}

output "enable_output_value" {
    value = "${ var.enable_output == false ? "" : data.null_data_source.value.outputs["var"]}"
}