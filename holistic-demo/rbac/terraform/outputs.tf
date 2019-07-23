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

output "admin_sa_key" {
  sensitive   = true
  description = "Admin Service Account Key in PEM/JSON"
  value       = base64decode(google_service_account_key.admin_key.private_key)
}

output "admin_sa_name" {
  description = "Admin Service Account Name"
  value       = google_service_account.admin.email
}

output "owner_sa_key" {
  sensitive   = true
  description = "Owner Service Account Key in PEM/JSON"
  value       = base64decode(google_service_account_key.owner_key.private_key)
}

output "owner_sa_name" {
  description = "Owner Service Account Name"
  value       = google_service_account.owner.email
}

output "auditor_sa_key" {
  sensitive   = true
  description = "Auditor Service Account Key in PEM/JSON"
  value       = base64decode(google_service_account_key.auditor_key.private_key)
}

output "auditor_sa_name" {
  description = "Auditor Service Account Name"
  value       = google_service_account.auditor.email
}
