variable "enable_output" {
    default = false
}

module "webserver_cluster" {
    source = "../../../modules/services/webserver-cluster"
    
    env                    = "dv"
    app                    = "baker"
    service                = "auth-api"
    vnet_address_space     = ["10.0.0.0/23"]
    frontend_subnet_prefix = "10.0.0.0/24"
    backend_subnet_prefix  = "10.0.1.0/24"

    enable_output          = "${var.enable_output}"

}

output "enable_output" {
    value = module.webserver_cluster.enable_output_value
}

output "lb_ip" {
    value = module.webserver_cluster.public_ip_lb
}