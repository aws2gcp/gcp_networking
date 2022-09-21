variable "project_id" {
  type        = string
  description = "Project ID of GCP Project"
}
variable "vpc_network_name" {
  type        = string
  description = "Name of VPC Network"
}
variable "description" {
  type        = string
  description = "Description of VPC Network"
  default     = null
}
variable "mtu" {
  description = "MTU for the VPC network: 1460 (default) or 1500"
  type        = number
  default     = null
}
variable "enable_global_routing" {
  description = "Enable Global Routing (default is Regional)"
  type        = bool
  default     = false
}
variable "subnet_defaults" {
  description = "Default settigns for all subnets (can be overridden)"
  type = object({
    enable_private_access    = bool
    enable_flow_logs         = bool
    log_aggregation_interval = string
    log_sample_rate          = number
    stack_type               = string
  })
  default = {
    enable_private_access    = false
    enable_flow_logs         = false
    log_aggregation_interval = "INTERVAL_5_SEC"
    log_sample_rate          = 0.5
    stack_type               = "IPV4_ONLY"
  }
}
variable "subnets" {
  description = "Subnets in this VPC Network"
  type = map(object({
    description              = optional(string)
    region                   = string
    stack_type               = optional(string)
    ip_range                 = string
    purpose                  = optional(string)
    role                     = optional(string)
    enable_private_access    = optional(bool)
    enable_flow_logs         = optional(bool)
    log_aggregation_interval = optional(string)
    log_sample_rate          = optional(number)
    secondary_ranges = optional(map(object({
      range = string
    })))
  }))
  default = {}
}
variable "routes" {
  description = "Static Routes"
  type = map(object({
    description   = optional(string)
    dest_range    = optional(string)
    dest_ranges   = optional(list(string))
    priority      = optional(number)
    instance_tags = optional(list(string))
    next_hop      = optional(string)
    next_hop_zone = optional(string)
  }))
  default = {}
}
variable "peerings" {
  description = "VPC Peering Connections"
  type = map(object({
    peer_project_id                     = optional(string)
    peer_network_name                   = string
    import_custom_routes                = optional(bool)
    export_custom_routes                = optional(bool)
    import_subnet_routes_with_public_ip = optional(bool)
    export_subnet_routes_with_public_ip = optional(bool)
  }))
  default = {}
}
variable "cloud_router_defaults" {
  description = "Default Settings for all Cloud Routers (can be overridden)"
  type = object({
    bgp_asn = number
  })
  default = {
    bgp_asn = 64512
  }
}
variable "cloud_routers" {
  description = "Cloud Routers attached to this VPC Network"
  type = map(object({
    description       = optional(string)
    region            = string
    bgp_asn           = optional(number)
    advertised_groups = optional(list(string))
    advertised_ip_ranges = optional(list(object({
      range       = string
      description = optional(string)
    })))
  }))
  default = {}
}
variable "cloud_nat_defaults" {
  description = "Default settings for all Cloud NATs (can be overridden)"
  type = object({
    min_ports_per_vm = optional(number)
    max_ports_per_vm = optional(number)
    timeouts         = optional(list(number))
    enable_dpa       = optional(bool)
    enable_eim       = optional(bool)
    log_type         = optional(string)
  })
  default = {
    min_ports_per_vm = 64
    timeouts         = [30, 1200, 30, 30]
    enable_eim       = false
    log_type         = "errors"
  }
}
variable "cloud_nats" {
  description = "Cloud NATs used by this VPC Network"
  type = map(object({
    region                 = string
    cloud_router_name      = optional(string)
    subnets                = optional(list(string))
    num_static_ips         = optional(number)
    static_ips             = optional(list(string))
    static_ip_names        = optional(list(string))
    static_ip_descriptions = optional(list(string))
    log_type               = optional(string)
    enable_dpa             = optional(bool)
    min_ports_per_vm       = optional(number)
    max_ports_per_vm       = optional(number)
    enable_eim             = optional(bool)
    timeouts               = optional(list(number))
  }))
  default = {}
}
variable "firewall_rules" {
  description = "Firewall Rules applied to this VPC Network"
  type = map(object({
    description        = optional(string)
    priority           = optional(number)
    direction          = optional(string)
    enable_logging     = optional(bool)
    source_ranges      = optional(list(string))
    source_tags        = optional(list(string))
    target_tags        = optional(list(string))
    destination_ranges = optional(list(string))
    service_accounts   = optional(list(string))
    allow = optional(list(object({
      protocol = string
      ports    = optional(list(string))
    })))
    deny = optional(list(object({
      protocol = string
      ports    = optional(list(string))
    })))
  }))
  default = {}
}
variable "interconnects" {
  description = "Dedicated and Partner Interconnects"
  type = map(object({
    type                 = string
    region               = optional(string)
    cloud_router_name    = optional(string)
    cloud_router_ip      = optional(string)
    bgp_peer_ip          = optional(string)
    peer_bgp_asn         = optional(number)
    advertised_priority  = optional(number)
    advertised_groups    = optional(list(string))
    advertised_ip_ranges = optional(list(string))
    mtu                  = optional(number)
    enabled              = optional(bool)
    enable_bfd           = optional(bool)
    bfd_parameters       = optional(list(number))
    circuits = list(object({
      interface_index      = optional(number)
      attachment_name      = optional(string)
      interface_name       = optional(string)
      name                 = optional(string)
      bgp_name             = optional(string)
      description          = optional(string)
      mtu                  = optional(number)
      cloud_router_ip      = optional(string)
      bgp_peer_ip          = optional(string)
      peer_bgp_asn         = optional(number)
      advertised_priority  = optional(number)
      advertised_groups    = optional(list(string))
      advertised_ip_ranges = optional(list(string))
    }))
  }))
  default = {}
}
variable "ip_ranges" {
  description = "Internal IP address ranges for private service connections"
  type = map(object({
    description = optional(string)
    ip_range    = string
  }))
  default = {}
}
variable "service_connections" {
  description = "Private Service Connections"
  type = map(object({
    service   = optional(string)
    ip_ranges = list(string)
  }))
  default = {}
}
variable "private_service_connections" {
  description = "Private Service Connections"
  type = map(object({
    target     = string
    ip_address = optional(string)
  }))
  default = {}
}
variable "private_service_connects" {
  description = "Private Service Connects"
  type = map(object({
    target        = string
    endpoint_name = optional(string)
    subnet_name   = optional(string)
    region        = optional(string)
    ip_address    = optional(string)
  }))
  default = {}
}
variable "vpc_access_connectors" {
  description = "Serverless VPC Access Connectors"
  type = map(object({
    region             = string
    cidr_range         = optional(string)
    subnet_name        = optional(string)
    vpc_network_name   = optional(string)
    network_project_id = optional(string)
    min_instances      = optional(number)
    max_instances      = optional(number)
    machine_type       = optional(string)
  }))
  default = {}
}
variable "cloud_vpn_gateways" {
  description = "Map of GCP Cloud VPN Gateways"
  type = map(object({
    region = string
  }))
  default = {}
}
variable "peer_vpn_gateways" {
  description = "Map of Peer (External) VPN Gateways"
  type = map(object({
    description  = optional(string)
    ip_addresses = list(string)
  }))
  default = {}
}
variable "vpns" {
  description = "Map of HA VPNs"
  type = map(object({
    comment                = optional(string)
    region                 = string
    cloud_vpn_gateway_name = optional(string)
    cloud_router_name      = optional(string)
    peer_vpn_gateway_name  = string
    peer_bgp_asn           = optional(number)
    advertised_priority    = optional(number)
    advertised_groups      = optional(list(string))
    advertised_ip_ranges   = optional(list(string))
    enable_bfd             = optional(bool)
    bfd_parameters         = optional(list(number))
    tunnels = list(object({
      vpn_name             = optional(string)
      interface_index      = optional(number)
      interface_name       = optional(string)
      description          = optional(string)
      ike_version          = optional(number)
      ike_psk              = string
      cloud_router_ip      = optional(string)
      bgp_name             = optional(string)
      bgp_peer_ip          = optional(string)
      peer_bgp_asn         = optional(number)
      advertised_priority  = optional(number)
      advertised_groups    = optional(list(string))
      advertised_ip_ranges = optional(list(string))
      enabled              = optional(bool)
    }))
  }))
  default = {}
}
variable "instances" {
  type = map(object({
    region                 = string
    num_instances          = optional(string)
    subnet_name            = optional(string)
    machine_type           = optional(string)
    os                     = optional(string)
    os_project             = optional(string)
    startup_script         = optional(string)
    service_account_email  = optional(string)
    service_account_scopes = optional(list(string))
    network_tags           = optional(list(string))
  }))
  default = {}
}
variable "instance_groups" {
  description = "Map of unmanaged instance groups"
  type = map(object({
    zone        = string
    instances   = list(string)
    description = optional(string)
  }))
  default = {}
}
variable "healthchecks" {
  description = "Map of Heath Checks"
  type = map(object({
    port         = optional(number)
    protocol     = optional(string)
    request_path = optional(string)
    response     = optional(string)
  }))
  default = {}
}
variable "l4_load_balancers" {
  description = "Map of L4 (TCP/UDP) Load balancers"
  type = map(object({
    instances_per_region  = optional(number)
    machine_type          = optional(string)
    os_project            = optional(string)
    os                    = optional(string)
    startup_script        = optional(string)
    service_account_email = optional(string)
    network_tags          = optional(list(string))
    ports                 = optional(list(string))
    network_project_id    = optional(string)
    healthcheck_name      = optional(string)
    affinity_type         = optional(string)
    allow_global_access   = optional(string)
    publish_to_psc        = optional(bool)
    psc_name              = optional(string)
    regions = map(object({
      subnet_name           = optional(string)
      ip_address            = optional(string)
      instance_groups       = optional(list(string))
      instance_groups_zones = optional(list(string))
      num_instances         = optional(number)
      allow_global_access   = optional(bool)
    }))
  }))
  default = {}
}
