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

set -x

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
# shellcheck source=scripts/istio.env
source "$ROOT/scripts/istio.env"
#ISTIO_DIR="$ROOT/istio-${ISTIO_VERSION}"

kubectl delete ns vm --ignore-not-found=true
kubectl delete ns bookinfo --ignore-not-found=true

kubectl delete -n default \
  -f "$ISTIO_DIR/samples/bookinfo/platform/kube/bookinfo.yaml"
kubectl delete -n default \
  -f "$ISTIO_DIR/samples/bookinfo/networking/bookinfo-gateway.yaml"
kubectl delete -n default \
  -f "$ISTIO_DIR/samples/bookinfo/networking/destination-rule-all-mtls.yaml"
kubectl delete -n default \
  -f "$ISTIO_DIR/samples/bookinfo/networking/virtual-service-reviews-v3.yaml"
kubectl delete -n default \
  -f "$ISTIO_DIR/samples/bookinfo/networking/virtual-service-ratings-mysql-vm.yaml"
kubectl delete -n default \
  -f "$ISTIO_DIR/samples/bookinfo/platform/kube/bookinfo-ratings-v2-mysql-vm.yaml"

# Wait until all LBs have been cleaned up by the addon manager
echo "Deleting Istio ILBs"
for ISTIO_LB_NAME in istio-ingressgateway istio-pilot-ilb mixer-ilb; do
  until [[ "$(kubectl get svc -n istio-system ${ISTIO_LB_NAME} -o=jsonpath="{.metadata.name}" --ignore-not-found=true)" == "" ]]; do
    echo "Waiting for istio-system ${ISTIO_LB_NAME} to be removed..."
    sleep 2
  done
done

# If kube-system/dns-lib svc is present, delete it
kubectl delete svc -n kube-system dns-ilb --ignore-not-found=true
# Wait until its gone
until [[ "$(kubectl get svc -n kube-system dns-ilb -o=jsonpath="{.metadata.name}" --ignore-not-found=true)" == "" ]]; do
  echo "Waiting for kube-system dns-ilb to be removed..."
  sleep 5
done

# Loop until the ILBs are fully gone
until [[ "$(gcloud --project="${ISTIO_PROJECT}" compute forwarding-rules list --format="value(name)" --filter "(description ~ istio-system.*ilb OR description:kube-system/dns-ilb) AND network ~ /istio-network$")" == "" ]]; do
  # Find all internal (ILB) forwarding rules in the network: istio-network
  FWDING_RULE_NAMES="$(gcloud --project="${ISTIO_PROJECT}" compute forwarding-rules list --format="value(name)" --filter "(description ~ istio-system.*ilb OR description:kube-system/dns-ilb) AND network ~ /istio-network$")"
  # Iterate and delete the forwarding rule by name and its corresponding backend-service by the same name
  for FWD_RULE in ${FWDING_RULE_NAMES}; do
    gcloud --project="${ISTIO_PROJECT}" compute forwarding-rules delete "${FWD_RULE}" --region="${REGION}" || true
    gcloud --project="${ISTIO_PROJECT}" compute backend-services delete "${FWD_RULE}" --region="${REGION}" || true
  done
  sleep 2
done

# Loop until the target-pools and health checks are fully gone
until [[ "$(gcloud --project="${ISTIO_PROJECT}" compute target-pools list --format="value(name)" --filter="(instances ~ gke-${ISTIO_CLUSTER})")" == "" && "$(gcloud --project="${ISTIO_PROJECT}" compute target-pools list --format="value(healthChecks)" --filter="(instances ~ gke-${ISTIO_CLUSTER})" | sed 's/.*\/\(k8s\-.*$\)/\1/g')" == "" ]]; do
  # Find all target pools with this cluster as the target by name
  TARGET_POOLS="$(gcloud --project="${ISTIO_PROJECT}" compute target-pools list --format="value(name)" --filter="(instances ~ gke-${ISTIO_CLUSTER})")"
  # Find all health checks with this cluster's nodes as the instances
  HEALTH_CHECKS="$( gcloud --project="${ISTIO_PROJECT}" compute target-pools list --format="value(healthChecks)" --filter="(instances ~ gke-${ISTIO_CLUSTER})" | sed 's/.*\/\(k8s\-.*$\)/\1/g')"
  # Delete the external (RLB) forwarding rules by name and the target pool by the same name
  for TARGET_POOL in ${TARGET_POOLS}; do
    gcloud --project="${ISTIO_PROJECT}" compute forwarding-rules delete "${TARGET_POOL}" --region="${REGION}" || true
    gcloud --project="${ISTIO_PROJECT}" compute target-pools delete "${TARGET_POOL}" --region="${REGION}" || true
  done
  # Delete the leftover health check by name
  for HEALTH_CHECK in ${HEALTH_CHECKS}; do
    gcloud --project="${ISTIO_PROJECT}" compute health-checks delete "${HEALTH_CHECK}" || true
  done
  sleep 2
done

# Delete all the firewall rules that aren't named like our cluster name which
# correspond to our health checks and load balancers that are dynamically created.
# This is because GKE manages those named with the cluster name get cleaned
# up with a terraform destroy.
until [[ "$(gcloud --project="${ISTIO_PROJECT}" compute firewall-rules list --format "value(name)"   --filter "targetTags.list():gke-${ISTIO_CLUSTER} AND NOT name ~ gke-${ISTIO_CLUSTER}")" == "" ]]; do
  FW_RULES="$(gcloud --project="${ISTIO_PROJECT}" compute firewall-rules list --format "value(name)"   --filter "targetTags.list():gke-${ISTIO_CLUSTER} AND NOT name ~ gke-${ISTIO_CLUSTER}")"
  for FW_RULE in ${FW_RULES}; do
    gcloud --project="${ISTIO_PROJECT}" compute firewall-rules delete "${FW_RULE}" || true
  done
  sleep 2
done

# Tear down all of the infrastructure created by Terraform
(cd "$ROOT/terraform"; terraform init; terraform destroy -input=false -auto-approve\
  -var "istio_project=${ISTIO_PROJECT}" \
  -var "gce_project=${GCE_PROJECT}" \
  -var "zone=${ZONE}" \
  -var "region=${REGION}" \
  -var "gce_network=${GCE_NETWORK}" \
  -var "gce_subnet=${GCE_SUBNET}" \
  -var "gce_subnet_cidr=${GCE_SUBNET_CIDR}" \
  -var "istio_network=${ISTIO_NETWORK}" \
  -var "istio_subnet_cidr=${ISTIO_SUBNET_CIDR}" \
  -var "istio_subnet_cluster_cidr=${ISTIO_SUBNET_CLUSTER_CIDR}" \
  -var "istio_subnet_services_cidr=${ISTIO_SUBNET_SERVICES_CIDR}" \
  -var "gce_vm=${GCE_VM}")

# Clean up the downloaded Istio components
if [[ -d "$ROOT/istio-$ISTIO_VERSION" ]]; then
  rm -rf istio-$ISTIO_VERSION
fi
