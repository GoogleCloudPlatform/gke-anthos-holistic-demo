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

/*
This file exposes variables that can be overridden to customize your cloud configuration.
https://www.terraform.io/docs/configuration/variables.html
*/

/*
Required Variables
These must be provided at runtime.
*/

variable "project" {
  description = "The name of the project in which to create the Kubernetes cluster."
  type        = string
}

variable "region" {
  description = "The region in which to create the Kubernetes cluster."
  type        = string
}

variable "cluster_name" {
  description = "The name of the already created Kubernetes Cluster."
  type        = string
}

