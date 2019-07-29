variable "enable_output" {
    default = false
}

module "webserver_cluster" {
    source = "../../../modules/services/webserver-cluster"

    env                    = "pd"
    app                    = "baker"
    service                = "auth-api"
    vnet_address_space     = ["10.0.2.0/23"]
    frontend_subnet_prefix = "10.0.2.0/24"
    backend_subnet_prefix  = "10.0.3.0/24"
    
    application_gateway_sku = {
        name     = "Standard_Small"
        tier     = "Standard"
        capacity = 4
    }

    vmss_sku = {
        name     = "Standard_DS1_v2"
        tier     = "Standard"
        capacity = 4
    }

    enable_output = "${var.enable_output}"

}

output "enable_ouput" {
    value = module.webserver_cluster.enable_output_value
}

output "lb_ip" {
    value = module.webserver_cluster.public_ip_lb
}