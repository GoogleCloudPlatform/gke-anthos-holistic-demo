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

// The project used to deploy the GKE cluster
variable "istio_project" {
}

// The project used to deploy the GCE instance
variable "gce_project" {
}

// The name of the network to create for the GKE cluster
variable "istio_network" {
}

// The name of the network to create for the GCE instance
variable "gce_network" {
}

// NOTE: The zone selected must reside in the selected region
// The region in which to deploy all regionally-scoped resources
variable "region" {
}

// The zone in which to deploy all zonally-scoped resources
variable "zone" {
}

// The CIDR used by the GKE cluster's subnet
variable "istio_subnet_cidr" {
}

// The alias IP CIDR used by the GKE cluster's pods
variable "istio_subnet_cluster_cidr" {
}

// The alias IP CIDR used by the GKE cluster's services
variable "istio_subnet_services_cidr" {
}

// The subnet used by the GCE instance
variable "gce_subnet" {
}

// The CIDR used by the GCE instance's subnet
variable "gce_subnet_cidr" {
}

// The name to use for the GCE instance
variable "gce_vm" {
}

