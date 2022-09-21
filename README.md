# Management of GCP VPC Network and related components:

- Subnets & IP Ranges
- Cloud Routers
- Cloud NATs
- VPNs
- Interconnects
- VPC Peering
- Static Routes
- Firewall Rules
- TCP/UDP Load Balancers
- Private Service Connects
- Healthchecks
- Instances 
- Instance Groups

## Subnets

```
subnets = {
  default-us-east1 = {
    region           = "us-east1"
    ip_range         = "10.1.2.0/24"
    enable_flow_logs = true
  }
  psc-us-east1 = {
  }
  proxy-only-us-east1 = {
  }
}
```

## Firewall Rules

```
firewall_rules = {
  gcp-healthchecks = {
    priority      = 999
    source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
  }
}
```

## Hybrid Connectivity
### Cloud Routers & Cloud NATs

```
cloud_routers = {
  cloudrouter-us-east1 = {
    region = "us-east1"
    bgp_asn = 65001
  }
  cloudrouter-europe-west4 = {
    region = "europe-west4"
    bgp_asn = 65004
  }
}
cloud_nats = {
  us-east1 = {
    region = "us-east1"
    cloud_router_name = "cloudrouter-us-east1"
    num_static_ips = 1
  }
  europe-west4 = {
    region = "europe-west4"
    cloud_router_name = "cloudrouter-europe-west4"
  }
}

```
### VPC Network Peering
```
peerings = {
  my-peer1 = {
    peer_project_id      = "some-other-project-id"
    peer_network_name    = "my-peered-network"
    import_custom_routes = true
  }
  my-peer2 = {
    peer_project_id      = "some-other-project-id"
    peer_network_name    = "my-other-peered-network"
    export_custom_routes = true
  }
}
```
### VPNs
```
peer_vpn_gateways = {
  office = {
  }
}
cloud_vpn_gateways = {
  us-east1 = {
    region = "us-east1"
  }
}
vpns = {
}
```

### Private IP Ranges and Private Service Connections

```
ip_ranges = {
  servicenetworking = {
    ip_range = "100.64.64.0/18"
  }
}
service_connections = {
  service-networking = {
    ip_ranges = ["servicenetworking"]
  }
}
```

### Private Service Connects

```
private_service_connects = {
  my-psc = {
    target      = "projects/some-other-gcp-project/regions/us-east1/serviceAttachments/some-service-name"
    region      = "us-east1"
    subnet_name = "default-us-east1"
    ip_address  = "192.0.2.50"
  }
}
```

## IMPORT examples

### Import existing subnet called 'test01' in region 'us-central1':

```
terraform import -var-file=my_vpc.tfvars 'module.subnets["test01"].google_compute_subnetwork.default' us-central1/test01
```

Import existing Private Service Connection
```
terraform import 'module.private_services[\"servicenetworking-googleapis-com\"].google_service_networking_connection.default' projects/MY_PROJECT/global/networks/MY_NETWORK:servicenetworking.googleapis.com
```
