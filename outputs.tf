output "peering_connections" {
  value = { for k, v in module.vpc_network_peering : k => v.state_details }
}
output "cloud_nats" {
  value = { for k, v in module.cloud_nats : k => v.region }
}
output "cloud_vpn_gateways" {
  value = { for k, v in module.cloud_vpn_gateway : k => { region = v.region, ip_addresses = v.ip_addresses } }
}
output "instances" {
  value = { for k, v in module.instances : k => { names = v.names, zones = v.zones, internal_ips = v.internal_ips } }
}
output "instances_external_ips" {
  value = { for k, v in module.instance_external_ips : k => v.addresses }
}
output "dns_zones" {
  value = { for k, v in module.dns_zones : k => v.dns_name }
}
output "dns_policies" {
  value = { for k, v in module.dns_policies : k => v.id }
}