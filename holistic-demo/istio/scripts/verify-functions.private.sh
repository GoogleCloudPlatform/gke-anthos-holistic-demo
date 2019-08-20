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

# Library of functions used by the deployment/teardown scripts

# Check if a cluster's firewalls exist
# Globals:
#   None
# Arguments:
#   PROJECT
#   CLUSTER
# Returns:
#   1
function firewall_exists() {
  local PROJECT="$1"
  local CLUSTER="$2"
  local EXISTS
  EXISTS=$(gcloud compute firewall-rules list --project "$PROJECT" --filter "name=$CLUSTER" --format "value(name)")
  if [[ "${EXISTS}" != "" ]]; then
    echo ""
    echo "the $CLUSTER_NAME firewalls exist"
    echo ""
    return 0
  fi
  return 1
}

# Check if a GCP project with the provided ID exists
# Globals:
#   None
# Arguments:
#   PROJECT
# Returns:
#   None
function project_exists() {
  local PROJECT="${1}"
  local EXISTS
  EXISTS=$(gcloud projects list --filter "projectId=${PROJECT}" --format "value(projectId)")
  if [[ "${EXISTS}" != "" ]]; then
    echo "The project ${PROJECT} exists"
    return 0
  fi
  return 1
}

# Check if a given network exists
# Globals:
#   None
# Arguments:
#   PROJECT
#   NETWORK
# Returns:
#   None
function network_exists() {
  local PROJECT="${1}"
  local NETWORK="${2}"
  local EXISTS
  EXISTS=$(gcloud compute networks list --project "${PROJECT}" --filter "name=${NETWORK}" --format "value(name)")
  if [[ "${EXISTS}" != "" ]]; then
    echo "The ${NETWORK} network exists"
    return 0
  fi
  return 1
}

# Check if a given network is not the last in the project
# Globals:
#   None
# Arguments:
#   PROJECT
#   NETWORK
# Returns:
#   None
function network_is_not_last() {
  local PROJECT="${1}"
  local NETWORK="${2}"
  local EXISTS
  EXISTS=$(gcloud compute networks list --project "${PROJECT}" --filter "NOT name=${NETWORK}" --format "value(name)")
  if [[ "${EXISTS}" != "" ]]; then
    echo "The ${NETWORK} network is not the last one in the project"
    return 0
  fi
  return 1
}

# Check if a cluster's firewalls exist
# Globals:
#   None
# Arguments:
#   PROJECT
#   INSTANCE
# Returns:
#   None
function instance_exists() {
  local PROJECT="${1}"
  local INSTANCE="${2}"
  local EXISTS
  EXISTS=$(gcloud compute instances list --project "${PROJECT}" --filter "name=${INSTANCE}" --format "value(name)")
  if [[ "${EXISTS}" == "${INSTANCE}" ]]; then
    echo "The instance ${INSTANCE} exists"
    return 0
  fi
  return 1
}

# Check if a cluster exists
# Globals:
#   None
# Arguments:
#   PROJECT
#   CLUSTER
# Returns:
#   None
function cluster_exists() {
  local PROJECT="${1}"
  local CLUSTER="${2}"
  local EXISTS
  EXISTS=$(gcloud container clusters list  --project "${PROJECT}" --filter "name=${CLUSTER}" --format "value(name)")
  if [[ "${EXISTS}" == "${CLUSTER}" ]]; then
    echo "The cluster ${CLUSTER} exists"
    return 0
  fi
  return 1
}


# Check if a directory exists
# Globals:
#   None
# Arguments:
#   DIR
# Returns:
#   None
function directory_exists() {
  local DIR="${1}"
  if [[ -d "${DIR}" ]]; then
    echo "The directory ${DIR} exists"
    return 0
  fi
  return 1
}

# Check if a file exists
# Globals:
#   None
# Arguments:
#   FILE
# Returns:
#   None
function file_exists() {
  local FILE="${1}"
  if [[ -e "${FILE}" ]]; then
    echo "The file ${FILE} exists"
    return 0
  fi
  return 1
}

# Check if required binaries exist
# Globals:
#   None
# Arguments:
#   None
# Returns:
#   None
function dependency_installed () {
  command -v "${1}" >/dev/null 2>&1 || exit 1
}

# Enable required API's that are not already enabled
# Globals:
#   None
# Arguments:
#   PROJECT
#   API
# Returns:
#   None
function enable_project_api() {
  # Check if the API is already enabled for the sake of speed
  if [[ $(gcloud services list --project="${1}" \
                                --format="value(serviceConfig.name)" \
                                --filter="serviceConfig.name:${2}" 2>&1) != \
                                "${2}" ]]; then
    echo "Enabling the API ${2}"
    gcloud services enable "${2}" --project="${1}"
  else
    echo "The API ${2} is already enabled for project ${1}"
  fi
}

# Check if a service with a given name is installed
# Globals:
#   None
# Arguments:
#   SERVICE_NAME - Name of service to check
#   RETRY_COUNT  - Number of times to retry
#   INTERVAL     - Amount of time to sleep between retries
#   NAMESPACE    - k8s namespace the service lives in
# Returns:
#   None
function service_is_installed () {
  # local SERVICE_NAME="${1}"
  # local RETRY_COUNT="${2}"
  # local SLEEP_INTERVAL="${3}"
  # local NAMESPACE="${4}"

  for ((i=0; i<${2}; i++)); do
    SERVICE=$(HTTPS_PROXY=localhost:8888 kubectl get -n "${4}" service "${1}" -o=name)
    if [ "${1}" == "" ] ; then
      echo "Attempt $((i + 1)): Service ${1} was not yet found in namespace ${4}" >&1
      sleep "${3}"
    else
      echo "Attempt $((i + 1)): Service ${1} has been created" >&1
      return 0
    fi
  done
  return 1
}

# Check if a service with the given label is running
# Globals:
#   None
# Arguments:
#   SERVICE_NAME - Name of service to check
#   RETRY_COUNT  - Number of times to retry
#   INTERVAL     - Amount of time to sleep between retries
#   NAMESPACE    - k8s namespace the service lives in
# Returns:
#   None
function service_ip_is_allocated () {
  local SERVICE="${1}"
  local RETRY_COUNT="${2}"
  local SLEEP="${3}"
  local NAMESPACE="${4}"

  for ((i=0; i<"${RETRY_COUNT}"; i++)); do
    IP=$(HTTPS_PROXY=localhost:8888 kubectl get -n "${NAMESPACE}" service "${SERVICE}" \
           -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    if [ "${IP}" == "" ] ; then
      echo "Attempt $((i + 1)): IP not yet allocated for service ${SERVICE}" >&1
    else
      echo "Attempt $((i + 1)): IP has been allocated for service ${SERVICE}" >&1
      return 0
    fi
    sleep "${SLEEP}"
  done
  echo "Timed out waiting for service ${SERVICE} to be allocated an IP address." >&1
  return 1
}

# Check if a pod with the given label is running
# Globals:
#   None
# Arguments:
#   POD_LABEL   - label applied to pod to check
#   RETRY_COUNT - Number of times to retry
#   INTERVAL    - Amount of time to sleep between retries
#   NAMESPACE   - k8s namespace the pod lives in
# Returns:
#   None
function pod_is_running () {
  local POD_LABEL="${1}"
  local RETRY_COUNT="${2}"
  local SLEEP="${3}"
  local NAMESPACE="${4}"
  for ((i=0; i<"${RETRY_COUNT}"; i++)); do
    POD=$(HTTPS_PROXY=localhost:8888 kubectl get -n "${NAMESPACE}" pod --selector="${POD_LABEL}" \
      --output=jsonpath="{.items[*].metadata.name}" \
      --field-selector=status.phase=Running)
    if [ "${POD}" == "" ] ; then
      echo "Attempt $((i + 1)): Waiting for pod ${POD_LABEL} in namespace ${NAMESPACE}..." >&1
      sleep "${SLEEP}"
    else
      echo "Attempt $((i + 1)): Pod ${POD_LABEL} is up and running" >&1
      return 0
    fi
  done
  echo "Timed out waiting for pod ${POD_LABEL} to start. Exiting..." >&1
  return 1
}
