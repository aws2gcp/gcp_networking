output "peering_connections" {
  value = { for k, v in module.vpc_network_peering : k => v.state_details }
}
output "cloud_nats" {
  value = { for k, v in module.cloud_nats : k => [v.region, v.nat_ips] }
}
output "cloud_vpn_gateways" {
  value = { for k, v in module.cloud_vpn_gateway : k => [v.region, v.ip_addresses] }
}
output "instances" {
  value = { for k, v in module.instances : k => [v.names, v.zones, v.internal_ips] }
}