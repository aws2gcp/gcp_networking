locals {
  subnet_defaults = {
    enable_private_access    = coalesce(var.subnet_defaults.enable_private_access, false)
    enable_flow_logs         = coalesce(var.subnet_defaults.enable_flow_logs, false)
    log_aggregation_interval = coalesce(var.subnet_defaults.log_aggregation_interval, "INTERVAL_5_SEC")
    log_sample_rate          = coalesce(var.subnet_defaults.log_sample_rate, "0.5")
    stack_type               = coalesce(var.subnet_defaults.stack_type, "IPV4_ONLY")
  }
  cloud_router_defaults = {
    bgp_asn = coalesce(var.cloud_router_defaults.bgp_asn, 64512)
  }
  cloud_nat_defaults = {
    min_ports_per_vm = coalesce(var.cloud_nat_defaults.min_ports_per_vm, 64)
    max_ports_per_vm = coalesce(var.cloud_nat_defaults.max_ports_per_vm, 2048)
    timeouts         = coalesce(var.cloud_nat_defaults.timeouts, [30, 1200, 30, 30])
    enable_dpa       = coalesce(var.cloud_nat_defaults.enable_dpa, true)
    enable_eim       = coalesce(var.cloud_nat_defaults.enable_eim, false)
    log_type         = coalesce(var.cloud_nat_defaults.log_type, "errors")
  }
}

# VPC Network
module "vpc_network" {
  source                = "../resources/google_compute_network"
  name                  = var.vpc_network_name
  description           = var.description
  mtu                   = var.mtu
  enable_global_routing = var.enable_global_routing
  project_id            = var.project_id
}

# Subnets
module "subnets" {
  source                   = "../resources/google_compute_subnetwork"
  vpc_network_name         = var.vpc_network_name
  for_each                 = var.subnets
  name                     = each.key
  description              = each.value.description
  region                   = each.value.region
  ip_range                 = each.value.ip_range
  purpose                  = coalesce(each.value.purpose, "PRIVATE")
  secondary_ranges         = each.value.secondary_ranges
  stack_type               = coalesce(each.value.stack_type, local.subnet_defaults.stack_type)
  enable_private_access    = coalesce(each.value.enable_private_access, local.subnet_defaults.enable_private_access)
  enable_flow_logs         = coalesce(each.value.enable_flow_logs, local.subnet_defaults.enable_flow_logs)
  log_aggregation_interval = coalesce(each.value.log_aggregation_interval, local.subnet_defaults.log_aggregation_interval)
  log_sample_rate          = coalesce(each.value.log_sample_rate, local.subnet_defaults.log_sample_rate)
  depends_on               = [module.vpc_network.id]
  project_id               = var.project_id
}

# Shared VPC Host Project
module "shared_vpc_host_project" {
  source          = "../resources/google_compute_shared_vpc_host_project"
  host_project_id = length(var.service_project_ids) > 0 ? var.project_id : null
}

# Shared VPC Service Projects
module "shared_vpc_service_project" {
  source             = "../resources/google_compute_shared_vpc_service_project"
  count              = length(var.service_project_ids)
  host_project_id    = var.project_id
  service_project_id = var.service_project_ids[count.index]
  depends_on         = [module.shared_vpc_host_project]
}

# Static Routes
module "routes" {
  source           = "../resources/google_compute_route"
  vpc_network_name = var.vpc_network_name
  for_each         = var.routes
  name             = each.key
  description      = each.value.description
  dest_range       = each.value.dest_range
  dest_ranges      = coalesce(each.value.dest_ranges, [])
  priority         = each.value.priority
  instance_tags    = each.value.instance_tags
  next_hop         = each.value.next_hop
  next_hop_zone    = each.value.next_hop_zone
  project_id       = var.project_id
}

# Cloud Routers
module "cloud_routers" {
  source                   = "../resources/google_compute_router"
  vpc_network_name         = var.vpc_network_name
  for_each                 = var.cloud_routers
  name                     = each.key
  description              = each.value.description
  region                   = each.value.region
  bgp_asn                  = coalesce(each.value.bgp_asn, local.cloud_router_defaults.bgp_asn)
  bgp_advertised_groups    = each.value.advertised_groups
  bgp_advertised_ip_ranges = each.value.advertised_ip_ranges
  depends_on               = [module.vpc_network]
  project_id               = var.project_id
}

# Allocate Static IP for each Cloud NAT, if required
module "cloud_nat_external_ips" {
  source        = "../resources/google_compute_address"
  for_each      = var.cloud_nats
  num_addresses = each.value.num_static_ips != null ? each.value.num_static_ips : each.value.static_ip_names != null ? length(each.value.static_ip_names) : 0
  address_type  = "EXTERNAL"
  region        = each.value.region
  name_prefix   = "cloudnat-${var.vpc_network_name}-${each.value.region}"
  names         = coalesce(each.value.static_ip_names, [])
  descriptions  = coalesce(each.value.static_ip_descriptions, [])
  project_id    = var.project_id
}

# Cloud NATs (NAT Gateways)
module "cloud_nats" {
  source            = "../resources/google_compute_router_nat"
  vpc_network_name  = var.vpc_network_name
  for_each          = var.cloud_nats
  name              = each.key
  region            = each.value.region
  cloud_router_name = coalesce(each.value.cloud_router_name, "${var.vpc_network_name}-${each.value.region}")
  subnets           = each.value.subnets != null ? each.value.subnets : []
  use_static_ip     = each.value.num_static_ips != null || each.value.static_ip_names != null ? true : false
  nat_ips           = coalesce(each.value.static_ip_names, module.cloud_nat_external_ips[each.key].names)
  min_ports_per_vm  = coalesce(each.value.min_ports_per_vm, local.cloud_nat_defaults.min_ports_per_vm)
  max_ports_per_vm  = coalesce(each.value.max_ports_per_vm, local.cloud_nat_defaults.max_ports_per_vm)
  enable_dpa        = coalesce(each.value.enable_dpa, local.cloud_nat_defaults.enable_dpa)
  enable_eim        = coalesce(each.value.enable_eim, local.cloud_nat_defaults.enable_eim)
  timeouts          = coalesce(each.value.timeouts, local.cloud_nat_defaults.timeouts)
  log_type          = coalesce(each.value.log_type, local.cloud_nat_defaults.log_type)
  depends_on        = [module.cloud_routers, module.cloud_nat_external_ips]
  project_id        = var.project_id
}

# Firewall rules
module "firewall_rules" {
  source             = "../resources/google_compute_firewall"
  vpc_network_name   = var.vpc_network_name
  for_each           = var.firewall_rules
  rule_name          = each.key
  rule_description   = each.value.description
  priority           = each.value.priority
  direction          = each.value.direction
  enable_logging     = each.value.enable_logging
  source_ranges      = each.value.source_ranges
  destination_ranges = each.value.destination_ranges
  allow              = each.value.allow
  deny               = each.value.deny
  source_tags        = each.value.source_tags
  target_tags        = each.value.target_tags
  service_accounts   = each.value.service_accounts
  depends_on         = [module.vpc_network]
  project_id         = var.project_id
}


# VPC Peering Connections
module "vpc_network_peering" {
  source                              = "../resources/google_compute_network_peering"
  for_each                            = var.peerings
  name                                = each.key
  vpc_network_name                    = var.vpc_network_name
  project_id                          = var.project_id
  peer_project_id                     = coalesce(each.value.peer_project_id, var.project_id)
  peer_network_name                   = each.value.peer_network_name
  import_custom_routes                = each.value.import_custom_routes
  export_custom_routes                = each.value.export_custom_routes
  import_subnet_routes_with_public_ip = coalesce(each.value.import_subnet_routes_with_public_ip, false)
  export_subnet_routes_with_public_ip = coalesce(each.value.export_subnet_routes_with_public_ip, true)
  depends_on                          = [module.vpc_network]
}

# Interconnect Attachments
module "interconnect_attachments" {
  source            = "../resources/google_compute_interconnect_attachment"
  for_each          = var.interconnects
  name_prefix       = each.key
  project_id        = var.project_id
  type              = each.value.type
  region            = each.value.region
  cloud_router_name = coalesce(each.value.cloud_router_name, "${var.vpc_network_name}-${each.value.region}")
  circuits          = each.value.circuits
  depends_on        = [module.cloud_routers]
}

# Interconnect Router Interfaces
module "interconnect_router_interfaces" {
  source            = "../resources/google_compute_router_interface"
  for_each          = var.interconnects
  type              = "interconnect"
  name_prefix       = each.key
  cloud_router_name = coalesce(each.value.cloud_router_name, "${var.vpc_network_name}-${each.value.region}")
  region            = each.value.region
  interfaces        = each.value.circuits
  #interconnect_attachments = [module.interconnect_attachments[each.key].ids]
  depends_on = [module.interconnect_attachments.ids]
}

# Interconnect BGP Sessions
module "interconnect_bgp_sessions" {
  source               = "../resources/google_compute_router_peer"
  for_each             = var.interconnects
  name_prefix          = each.key
  cloud_router_name    = coalesce(each.value.cloud_router_name, "${var.vpc_network_name}-${each.value.region}")
  region               = each.value.region
  bgp_peers            = each.value.circuits
  peer_bgp_asn         = each.value.peer_bgp_asn
  advertised_priority  = each.value.advertised_priority
  advertised_groups    = each.value.advertised_groups
  advertised_ip_ranges = each.value.advertised_ip_ranges
  enable_bfd           = coalesce(each.value.enable_bfd, false)
  bfd_parameters       = coalesce(each.value.bfd_parameters, [])
  depends_on           = [module.interconnect_router_interfaces.ids]
}

# Cloud VPN Gateways
module "cloud_vpn_gateway" {
  source           = "../resources/google_compute_ha_vpn_gateway"
  for_each         = var.cloud_vpn_gateways
  name             = each.key
  vpc_network_name = var.vpc_network_name
  region           = each.value.region
  depends_on       = [module.vpc_network.id]
  project_id       = var.project_id
}

# Peer (External) VPN Gateways
module "peer_vpn_gateway" {
  source       = "../resources/google_compute_external_vpn_gateway"
  for_each     = var.peer_vpn_gateways
  name         = each.key
  description  = each.value.description
  ip_addresses = each.value.ip_addresses
  project_id   = var.project_id
}

# Cloud VPN Tunnels
module "vpn_tunnels" {
  source                 = "../resources/google_compute_vpn_tunnel"
  for_each               = var.vpns
  region                 = each.value.region
  cloud_router_name      = coalesce(each.value.cloud_router_name, "${var.vpc_network_name}-${each.value.region}")
  cloud_vpn_gateway_name = each.value.cloud_vpn_gateway_name
  peer_vpn_gateway_name  = each.value.peer_vpn_gateway_name
  vpc_network_name       = var.vpc_network_name
  tunnels                = each.value.tunnels
  depends_on             = [module.cloud_vpn_gateway, module.peer_vpn_gateway, module.cloud_routers]
  project_id             = var.project_id
}

# Cloud Router interface IP addresses
module "vpn_router_interfaces" {
  source                = "../resources/google_compute_router_interface"
  for_each              = var.vpns
  type                  = "vpn"
  cloud_router_name     = coalesce(each.value.cloud_router_name, "${var.vpc_network_name}-${each.value.region}")
  region                = each.value.region
  name_prefix           = each.value.cloud_router_name != null ? "${each.value.cloud_router_name}-${each.value.peer_vpn_gateway_name}" : "${var.vpc_network_name}-${each.value.region}-${each.value.peer_vpn_gateway_name}"
  interfaces            = each.value.tunnels
  peer_vpn_gateway_name = each.value.peer_vpn_gateway_name
  depends_on            = [module.vpn_tunnels]
  project_id            = var.project_id
}

# VPN BGP Sessions
module "vpn_bgp_sessions" {
  source                = "../resources/google_compute_router_peer"
  for_each              = var.vpns
  region                = each.value.region
  cloud_router_name     = coalesce(each.value.cloud_router_name, "${var.vpc_network_name}-${each.value.region}")
  peer_vpn_gateway_name = each.value.peer_vpn_gateway_name
  peer_bgp_asn          = each.value.peer_bgp_asn
  advertised_priority   = each.value.advertised_priority
  advertised_groups     = each.value.advertised_groups
  advertised_ip_ranges  = each.value.advertised_ip_ranges
  bgp_peers             = each.value.tunnels
  depends_on            = [module.vpn_router_interfaces.ids]
  project_id            = var.project_id
}

# IP Ranges for Services
module "ip_ranges" {
  source           = "../resources/google_compute_global_address"
  for_each         = var.ip_ranges
  vpc_network_name = var.vpc_network_name
  names            = [each.key]
  descriptions     = [each.value.description]
  prefixes         = [each.value.ip_range]
  address_type     = "INTERNAL"
  purpose          = "VPC_PEERING"
  depends_on       = [module.vpc_network]
  project_id       = var.project_id
}

# Private Service Connections 
module "private_services" {
  source           = "../resources/google_service_networking_connection"
  for_each         = var.service_connections
  vpc_network_name = var.vpc_network_name
  service          = each.value.service
  ranges           = each.value.ip_ranges
  depends_on       = [module.vpc_network, module.ip_ranges]
}

# Private Service Connection (client) IP ranges 
module "psc_global_ip" {
  source           = "../resources/google_compute_global_address"
  for_each         = var.private_service_connections
  addresses        = each.value.target == "all-apis" ? [each.value.ip_address] : []
  name_prefix      = each.key
  vpc_network_name = var.vpc_network_name
  address_type     = "INTERNAL"
  purpose          = "PRIVATE_SERVICE_CONNECT"
  depends_on       = [module.vpc_network]
}

# Private Service Connection (client) Forwarding Rules
module "psc_global_fwdrule" {
  source           = "../resources/google_compute_global_forwarding_rule"
  for_each         = var.private_service_connections
  name             = each.key
  vpc_network_name = var.vpc_network_name
  ip_address       = module.psc_global_ip[each.key].ids[0]
  port_range       = null
  tproxy_id        = each.value.target
  lb_scheme        = ""
}

# Private Service Connect (client) IP addresses 
module "psc_subnet_ip" {
  source             = "../resources/google_compute_address"
  for_each           = var.private_service_connects
  addresses          = [each.value.ip_address]
  region             = each.value.region
  subnet_name        = each.value.subnet_name
  name_prefix        = each.key
  network_project_id = var.project_id
  address_type       = "INTERNAL"
  purpose            = "GCE_ENDPOINT"
  project_id         = var.project_id
  depends_on         = [module.subnets]
}

# Private Service Connect (client) Forwarding Rules
module "psc_subnet_fwdrule" {
  source             = "../resources/google_compute_forwarding_rule"
  for_each           = var.private_service_connects
  name               = each.key
  network_project_id = var.project_id
  region             = each.value.region
  vpc_network_name   = var.vpc_network_name
  subnet_name        = each.value.subnet_name
  ip_address         = module.psc_subnet_ip[each.key].ids[0]
  port_range         = null
  target_id          = each.value.target
  lb_scheme          = ""
}

# Serverless VPC access connectors
module "vpc_access_connectors" {
  source             = "../resources/google_vpc_access_connector"
  for_each           = var.vpc_access_connectors
  name               = each.key
  project_id         = var.project_id
  vpc_network_name   = each.value.network_project_id != null ? each.value.vpc_network_name : var.vpc_network_name
  region             = each.value.region
  cidr_range         = each.value.cidr_range
  subnet_name        = each.value.subnet_name
  network_project_id = each.value.network_project_id
  min_instances      = each.value.min_instances
  max_instances      = each.value.max_instances
  machine_type       = each.value.machine_type
}

# Standalone Unmanaged Instance Groups
module "instance_groups" {
  source             = "../resources/google_compute_instance_group"
  project_id         = var.project_id
  for_each           = var.instance_groups
  name               = each.key
  network_project_id = var.project_id
  vpc_network_name   = var.vpc_network_name
  instances          = each.value.instances
  zone               = each.value.zone
}

# Reserve external IPs for instances with NAT
module "instance_external_ips" {
  source        = "../resources/google_compute_address"
  for_each      = var.instances
  num_addresses = each.value.nat_ip_names != null ? length(each.value.nat_ip_names) : 0
  project_id    = var.project_id
  region        = each.value.region
  names         = each.value.nat_ip_names
  address_type  = "EXTERNAL"
}

# Instances
module "instances" {
  source                = "../resources/google_compute_instance"
  for_each              = var.instances
  project_id            = var.project_id
  name                  = each.key
  description           = each.value.description
  vpc_network_name      = var.vpc_network_name
  region                = each.value.region
  num_instances         = each.value.num_instances
  machine_type          = each.value.machine_type
  boot_disk_type        = each.value.boot_disk_type
  boot_disk_size        = each.value.boot_disk_size
  image                 = each.value.image
  os_project            = each.value.os_project
  os                    = each.value.os
  subnet_name           = each.value.subnet_name
  service_account_email = each.value.service_account_email
  network_tags          = each.value.network_tags
  startup_script        = each.value.startup_script
  ssh_key               = each.value.ssh_key
  enable_ip_forwarding  = each.value.enable_ip_forwarding
  nat_ips               = each.value.nat_ip_names == null ? [] : module.instance_external_ips[each.key].addresses
}

# Create Unmanaged instance groups for load balanced instances
module "instance_instance_groups" {
  source           = "../resources/google_compute_instance_groups"
  for_each         = var.instances
  project_id       = var.project_id
  region           = each.value.region
  name             = "${each.key}-${each.value.region}"
  vpc_network_name = var.vpc_network_name
  instances        = each.value.create_instance_groups == true ? module.instances[each.key].self_links : []
  zones            = module.instances[each.key].zones
}

# DNS Zones
module "dns_zones" {
  source           = "../resources/google_dns_managed_zone"
  for_each         = var.dns_zones
  project_id       = var.project_id
  name             = each.key
  description      = each.value.description
  dns_name         = each.value.dns_name
  visibility       = each.value.visibility
  visible_networks = each.value.visibility == "private" ? coalesce(each.value.visible_networks, [var.vpc_network_name]) : []
  logging          = each.value.logging
}

# DNS Policies
module "dns_policies" {
  source              = "../resources/google_dns_policy"
  for_each            = var.dns_policies
  project_id          = var.project_id
  name                = each.key
  description         = each.value.description
  logging             = each.value.logging
  target_name_servers = {}
}

# DNS records
module "dns_records" {
  source     = "../resources/google_dns_record_set"
  for_each   = var.dns_zones
  project_id = var.project_id
  zone_name  = each.key
  dns_name   = module.dns_zones[each.key].dns_name
  records    = coalesce(each.value.records, {})
}

# Create A records for instances with external DNS
module "instance_private_dns" {
  source     = "../resources/google_dns_record_set"
  for_each   = var.instances
  project_id = var.project_id
  zone_name  = each.value.private_zone
  dns_name   = each.value.private_zone != null ? module.dns_zones[each.value.private_zone].dns_name : ""
  records = {
    for index, name in module.instances[each.key].names :
    name => {
      type    = "A"
      ttl     = var.dns_ttl
      rrdatas = length(module.instances[each.key].internal_ips) > 0 ? [module.instances[each.key].internal_ips[index]] : []
    }
  }
}

# Create A records for instances with external DNS
module "instance_public_dns" {
  source     = "../resources/google_dns_record_set"
  for_each   = var.instances
  project_id = var.project_id
  zone_name  = each.value.public_zone
  dns_name   = each.value.public_zone != null ? module.dns_zones[each.value.public_zone].dns_name : ""
  records = {
    for index, name in module.instances[each.key].names :
    name => {
      type    = "A"
      ttl     = var.dns_ttl
      rrdatas = length(module.instances[each.key].external_ips) > 0 ? [module.instances[each.key].external_ips[index]] : []
    }
  }
}
