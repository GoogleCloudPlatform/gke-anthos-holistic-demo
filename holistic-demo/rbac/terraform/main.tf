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
Defines a random string to use as our role name suffix to ensure uniqueness.
See https://www.terraform.io/docs/providers/random/r/string.html
*/
resource "random_string" "role_suffix" {
  length  = 8
  special = false
}

/*
Define a read-only role for API access
See https://www.terraform.io/docs/providers/google/r/google_project_iam_custom_role.html
*/
resource "google_project_iam_custom_role" "kube-api-ro" {
  // Randomize the name to avoid collisions with deleted roles
  // (Deleted roles prevent similarly named roles from being created for up to 30 days)
  // See https://cloud.google.com/iam/docs/creating-custom-roles#deleting_a_custom_role
  role_id = format("kube_api_ro_%s", random_string.role_suffix.result)

  title       = "Kubernetes API (RO)"
  description = "Grants read-only API access that can be further restricted with RBAC"

  permissions = [
    "container.apiServices.get",
    "container.apiServices.list",
    "container.clusters.get",
    "container.clusters.getCredentials",
  ]
}

resource "google_service_account" "owner" {
  account_id   = "gke-tutorial-owner-rbac"
  display_name = "GKE Tutorial Owner RBAC"
}

resource "google_service_account" "auditor" {
  account_id   = "gke-tutorial-auditor-rbac"
  display_name = "GKE Tutorial Auditor RBAC"
}

resource "google_service_account" "admin" {
  account_id   = "gke-tutorial-admin-rbac"
  display_name = "GKE Tutorial Admin RBAC"
}

resource "google_service_account_key" "owner_key" {
  service_account_id = "${google_service_account.owner.name}"
}

resource "google_service_account_key" "auditor_key" {
  service_account_id = "${google_service_account.auditor.name}"
}

resource "google_service_account_key" "admin_key" {
  service_account_id = "${google_service_account.admin.name}"
}

resource "google_project_iam_binding" "kube-api-ro" {
  role = format("projects/%s/roles/%s", var.project, google_project_iam_custom_role.kube-api-ro.role_id)

  members = [
    format("serviceAccount:%s", google_service_account.owner.email),
    format("serviceAccount:%s", google_service_account.auditor.email),
  ]
}

resource "google_project_iam_member" "kube-api-admin" {
  project = var.project
  role    = "roles/container.admin"
  member  = format("serviceAccount:%s", google_service_account.admin.email)
}

// https://www.terraform.io/docs/providers/template/index.html
// render the rbac.yaml to include generated service account names
data "template_file" "rbac_yaml" {
  template = "${file("${path.module}/templates/rbac.yaml")}"

  vars = {
    auditor_email = google_service_account.auditor.email
    owner_email   = google_service_account.owner.email
  }
}

resource "null_resource" "render_rbac_yaml" {
  provisioner "local-exec" {
    command = "echo \"${data.template_file.rbac_yaml.rendered}\" > '${path.module}/../manifests/rbac.yaml'"
  }
}

data "google_container_cluster" "base_cluster" {
  name       = var.cluster_name
  location   = var.region
}

resource "null_resource" "cluster_admin_binding" {
  provisioner "local-exec" {
    on_failure = "continue"
    command = "kubectl get clusterrolebinding gke-tutorial-admin-binding &> /dev/null || kubectl create clusterrolebinding gke-tutorial-admin-binding --clusterrole cluster-admin --user ${google_service_account.admin.email}"
    environment = {
      HTTPS_PROXY = "localhost:8888"
    }
  }
  depends_on = [google_service_account.admin]
}
