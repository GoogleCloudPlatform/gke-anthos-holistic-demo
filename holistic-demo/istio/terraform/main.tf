/*
Copyright 2018 Google LLC

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    https://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

# # Create a new networks to be used for the demo in the project housing the GCE instance.

resource "google_compute_network" "gce" {
  name                    = var.gce_network
  auto_create_subnetworks = "false"
  project                 = var.gce_project
}

# Create a regular subnet to be used by the GCE instance.
resource "google_compute_subnetwork" "subnet_gce" {
  name          = var.gce_subnet
  network       = google_compute_network.gce.self_link
  ip_cidr_range = var.gce_subnet_cidr
  project       = var.gce_project
  region        = var.region
}

# All of the forwarding rule, VPN gateway, IP address, and tunnel resources are
# necessary for a properly functioning VPN. For more information on why these
# resources are required, see the explanation provided for creating a route-
# based VPN using gcloud:
# https://cloud.google.com/vpn/docs/how-to/creating-route-based-vpns
resource "google_compute_vpn_gateway" "target_gateway_istio" {
  name    = "vpn-istio"
  project = var.istio_project
  network = join("", ["projects/", var.istio_project, "/global/networks/", var.istio_network])
  region  = var.region
}

resource "google_compute_vpn_gateway" "target_gateway_gce" {
  name    = "vpn-gce"
  project = var.gce_project
  network = google_compute_network.gce.self_link
  region  = google_compute_subnetwork.subnet_gce.region
}

resource "google_compute_address" "vpn_static_ip_istio" {
  name    = "vpn-static-ip-istio"
  project = var.istio_project
  region  = var.region
}

resource "google_compute_address" "vpn_static_ip_gce" {
  name    = "vpn-static-ip-gce"
  project = var.gce_project
  region  = google_compute_subnetwork.subnet_gce.region
}

resource "google_compute_forwarding_rule" "fr_esp_istio" {
  name        = "fr-esp-istio"
  ip_protocol = "ESP"
  ip_address  = google_compute_address.vpn_static_ip_istio.address
  target      = google_compute_vpn_gateway.target_gateway_istio.self_link
  project     = var.istio_project
}

resource "google_compute_forwarding_rule" "fr_esp_gce" {
  name        = "fr-esp-gce"
  ip_protocol = "ESP"
  ip_address  = google_compute_address.vpn_static_ip_gce.address
  target      = google_compute_vpn_gateway.target_gateway_gce.self_link
  project     = var.gce_project
}

resource "google_compute_forwarding_rule" "fr_udp500_istio" {
  name        = "fr-udp500-istio"
  ip_protocol = "UDP"
  port_range  = "500-500"
  ip_address  = google_compute_address.vpn_static_ip_istio.address
  target      = google_compute_vpn_gateway.target_gateway_istio.self_link
  project     = var.istio_project
}

resource "google_compute_forwarding_rule" "fr_udp500_gce" {
  name        = "fr-udp500-gce"
  ip_protocol = "UDP"
  port_range  = "500-500"
  ip_address  = google_compute_address.vpn_static_ip_gce.address
  target      = google_compute_vpn_gateway.target_gateway_gce.self_link
  project     = var.gce_project
}

resource "google_compute_forwarding_rule" "fr_udp4500_gce" {
  name        = "fr-udp4500-gce"
  ip_protocol = "UDP"
  port_range  = "4500-4500"
  ip_address  = google_compute_address.vpn_static_ip_gce.address
  target      = google_compute_vpn_gateway.target_gateway_gce.self_link
  project     = var.gce_project
}

resource "google_compute_forwarding_rule" "fr_udp4500_istio" {
  name        = "fr-udp4500-istio"
  ip_protocol = "UDP"
  port_range  = "4500-4500"
  ip_address  = google_compute_address.vpn_static_ip_istio.address
  target      = google_compute_vpn_gateway.target_gateway_istio.self_link
  project     = var.istio_project
}

resource "google_compute_vpn_tunnel" "tunnel1_istio" {
  name          = "tunnel1-istio"
  peer_ip       = google_compute_address.vpn_static_ip_gce.address
  shared_secret = "a secret message"
  project       = var.istio_project

  target_vpn_gateway = google_compute_vpn_gateway.target_gateway_istio.self_link

  local_traffic_selector = ["0.0.0.0/0"]

  remote_traffic_selector = ["0.0.0.0/0"]

  depends_on = [
    google_compute_forwarding_rule.fr_esp_istio,
    google_compute_forwarding_rule.fr_udp500_istio,
    google_compute_forwarding_rule.fr_udp4500_istio,
  ]
}

resource "google_compute_vpn_tunnel" "tunnel1_gce" {
  name          = "tunnel1-gce"
  peer_ip       = google_compute_address.vpn_static_ip_istio.address
  shared_secret = "a secret message"
  project       = var.gce_project

  target_vpn_gateway = google_compute_vpn_gateway.target_gateway_gce.self_link

  local_traffic_selector = ["0.0.0.0/0"]

  remote_traffic_selector = ["0.0.0.0/0"]

  depends_on = [
    google_compute_forwarding_rule.fr_esp_gce,
    google_compute_forwarding_rule.fr_udp500_gce,
    google_compute_forwarding_rule.fr_udp4500_gce,
  ]
}

# Ensures that traffic in the Istio project destined for the GCE VM is routed
# to the VPN
resource "google_compute_route" "route_istio" {
  name       = "route-istio"
  network    = join("", ["projects/", var.istio_project, "/global/networks/", var.istio_network])
  dest_range = google_compute_subnetwork.subnet_gce.ip_cidr_range
  priority   = 1000
  project    = var.istio_project

  next_hop_vpn_tunnel = google_compute_vpn_tunnel.tunnel1_istio.self_link
}

# Ensures that traffic destined for a pod in the GKE cluster in the GCE project
# is routed to the VPN
resource "google_compute_route" "route_gce_cluster_cidr" {
  name    = "route-istio-cluster-cidr"
  network = google_compute_network.gce.name

  # TODO: figure out how to use declared subnet ranges instead of the variable
  dest_range = var.istio_subnet_cluster_cidr
  priority   = 1000
  project    = var.gce_project

  next_hop_vpn_tunnel = google_compute_vpn_tunnel.tunnel1_gce.self_link
}

# Ensures that traffic destined for a service in the GKE cluster from the GCE \
# project is routed to the VPN
resource "google_compute_route" "route_gce_services_cidr" {
  name    = "route-istio-services-cidr"
  network = google_compute_network.gce.name

  # TODO: figure out how to use declared subnet ranges instead of the variable
  dest_range = var.istio_subnet_services_cidr
  priority   = 1000
  project    = var.gce_project

  next_hop_vpn_tunnel = google_compute_vpn_tunnel.tunnel1_gce.self_link
}

# Routes traffic destined for the GKE cluster subnet in the GCE project over
# the VPN
resource "google_compute_route" "route_gce" {
  name       = "route-gce"
  network    = google_compute_network.gce.name
  dest_range = var.istio_subnet_cidr
  priority   = 1000
  project    = var.gce_project

  next_hop_vpn_tunnel = google_compute_vpn_tunnel.tunnel1_gce.self_link
}

# Allows SSH traffic from anywhere to the database VM
resource "google_compute_firewall" "allow_ssh" {
  name    = "allow-gce-ssh"
  project = var.gce_project
  network = google_compute_network.gce.name

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["mysql"]

  allow {
    ports    = ["22"]
    protocol = "tcp"
  }
}

# Allows database traffic from the GKE cluster to the database VM
resource "google_compute_firewall" "allow_mysql" {
  name    = "allow-gce-mysql"
  project = var.gce_project
  network = google_compute_network.gce.name

  source_ranges = [
    var.istio_subnet_cluster_cidr,
    var.istio_subnet_services_cidr,
  ]

  target_tags = ["mysql"]

  allow {
    protocol = "tcp"
    ports    = ["3306"]
  }
}

# Creates a GCE instance to be used for the database. The tag is necessary to
# apply the correct firewall rules.
resource "google_compute_instance" "default" {
  name         = var.gce_vm
  machine_type = "n1-standard-1"
  project      = var.gce_project
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-10"
    }
  }

  tags = ["mysql"]

  network_interface {
    subnetwork = google_compute_subnetwork.subnet_gce.self_link
    access_config {
    }
  }
}
