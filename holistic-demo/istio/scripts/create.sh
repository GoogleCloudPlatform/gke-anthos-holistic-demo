#! /usr/bin/env bash

# Copyright 2018 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e
set -x

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
source $ROOT/scripts/setenvironment.sh

# Check if all required variables are non-null
# Globals:
#   None
# Arguments:
#   VAR - The variable to check
# Returns:
#   None
variable_is_set() {
  if [[ -z "${VAR}" ]]; then
    echo "Variable is not set. Please check your istio.env file."
    return 1
  fi
  return 0
}

# Check if required binaries exist
# Globals:
#   None
# Arguments:
#   DEPENDENCY - The command to verify is installed.
# Returns:
#   None
dependency_installed () {
  command -v "${1}" >/dev/null 2>&1 || exit 1
}

# Helper function to enable a given service for a given project
# Globals:
#   None
# Arguments:
#   PROJECT - ID of the project in which to enable the API
#   API     - Name of the API to enable, e.g. compute.googleapis.com
# Returns:
#   None
enable_project_api() {
  gcloud services enable "${2}" --project "${1}"
}

# set to jenkins if there is no $USER
USER=$(whoami)
[[ "${USER}" == "root" ]] && export USER=jenkins
echo "user is: $USER"

# Provide the default values for the variables
for VAR in "${ISTIO_CLUSTER}" "${ZONE}" "${REGION}" "${GCE_NETWORK}" \
           "${GCE_SUBNET}" "${GCE_SUBNET_CIDR}" "${ISTIO_NETWORK}" \
           "${ISTIO_SUBNET}" "${ISTIO_SUBNET_CIDR}" \
           "${ISTIO_SUBNET_CLUSTER_CIDR}" "${ISTIO_SUBNET_SERVICES_CIDR}" \
           "${GCE_VM}" "${ISTIO_GKE_VERSION}"; do
  variable_is_set "${VAR}"
done

# Ensure the necessary dependencies are installed
if ! dependency_installed "gcloud"; then
  echo "I require gcloud but it's not installed. Aborting."
fi

if ! dependency_installed "kubectl"; then
  echo "I require kubectl but it's not installed. Aborting."
fi

if ! dependency_installed "curl" ; then
  echo "I require curl but it's not installed. Aborting."
fi

if [[ "${ISTIO_PROJECT}" == "" ]]; then
  echo "ISTIO_PROJECT variable in istio.env is not set to a valid project. Aborting..."
  exit 1
fi

if [[ ${GCE_PROJECT} == "" ]]; then
  echo "GCE_PROJECT variable in istio.env is not set to a valid project. Aborting..."
  exit 1
fi

enable_project_api "${ISTIO_PROJECT}" compute.googleapis.com
enable_project_api "${ISTIO_PROJECT}" container.googleapis.com
enable_project_api "${GCE_PROJECT}" compute.googleapis.com

source $ROOT/scripts/terraformcreation.sh

if [[ ! "$(kubectl get clusterrolebinding --field-selector metadata.name=cluster-admin-binding \
                                          -o jsonpath='{.items[*].metadata.name}')" ]]; then

  kubectl create clusterrolebinding cluster-admin-binding \
    --clusterrole=cluster-admin --user="$(gcloud config get-value core/account)"
fi

# Add label to enable Envoy auto-injection
# TODO : remove this line. add comment to replace namespace default file in repo (anthos config-management)
kubectl label namespace default istio-injection=enabled --overwrite=true

# wait for istio-system to be created
until [ "$(kubectl get ns  | grep -c  istio-system)" -eq "1" ]; do echo 'waiting for ns istio-system to be created'; sleep 1; done

# Install the ILBs necessary for mesh expansion
# Move file into repo. Split it by namespace in your repo.
kubectl apply -f "$ISTIO_DIR/install/kubernetes/mesh-expansion.yaml"

# # Start of mesh expansion

# Configure kubectl
gcloud container clusters get-credentials --project ${ISTIO_PROJECT} --region ${REGION} --internal-ip demo-cluster

# Create the namespace to be used by the service on the VM. Split into two files in your repo.
kubectl apply -f "$ROOT/scripts/namespaces.yaml"


source $ROOT/scripts/meshsetup.sh

(
# # Register the external service with the Istio mesh
chmod +x "$ISTIO_DIR/bin/istioctl"
"$ISTIO_DIR/bin/istioctl" register -n vm mysqldb "$(gcloud compute instances describe "${GCE_VM}" \
  --format='value(networkInterfaces[].networkIP)' --project "${GCE_PROJECT}" --zone "${ZONE}")" 3306
)


# Install the bookinfo services and deployments and set up the initial Istio
# routing. For more information on routing see this Istio blog post:
# https://istio.io/blog/2018/v1alpha3-routing/
kubectl apply -n default \
  -f "$ISTIO_DIR/samples/bookinfo/platform/kube/bookinfo.yaml"
kubectl apply -n default \
  -f "$ISTIO_DIR/samples/bookinfo/networking/bookinfo-gateway.yaml"
kubectl apply -n default \
  -f "$ISTIO_DIR/samples/bookinfo/networking/destination-rule-all-mtls.yaml"

# Change the routing to point to the most recent versions of the bookinfo
# microservices
kubectl apply -n default \
  -f "$ISTIO_DIR/samples/bookinfo/networking/virtual-service-reviews-v3.yaml"
kubectl apply -n default \
  -f "$ISTIO_DIR/samples/bookinfo/networking/virtual-service-ratings-mysql-vm.yaml"
kubectl apply -n default \
  -f "$ISTIO_DIR/samples/bookinfo/platform/kube/bookinfo-ratings-v2-mysql-vm.yaml"

# Install and deploy the database used by the Istio service
gcloud compute ssh "${GCE_VM}" --project="${GCE_PROJECT}" --zone "${ZONE}" \
  --command "$(cat "$ROOT"/scripts/setup-gce-vm.sh)"

source $ROOT/scripts/getwebsiteinfo.sh