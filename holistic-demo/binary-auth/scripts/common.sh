#!/usr/bin/env bash

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

# "---------------------------------------------------------"
# "-                                                       -"
# "-  Common functions                                     -"
# "-                                                       -"
# "---------------------------------------------------------"

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

# "---------------------------------------------------------"
# "-                                                       -"
# "-  Common commands for all scripts                      -"
# "-                                                       -"
# "---------------------------------------------------------"


# gcloud and kubectl are required for this POC
command -v gcloud >/dev/null 2>&1 || { \
 echo >&2 "I require gcloud but it's not installed.  Aborting."; exit 1; }
command -v kubectl >/dev/null 2>&1 || { \
 echo >&2 "I require kubectl but it's not installed.  Aborting."; exit 1; }


# Get the default zone and use it or die
ZONE=$(gcloud config get-value compute/zone)
if [ -z "${ZONE}" ]; then
    echo "gcloud cli must be configured with a default zone." 1>&2
    echo "run 'gcloud config set compute/zone ZONE'." 1>&2
    echo "replace 'ZONE' with the zone name like us-west1-a." 1>&2
    exit 1;
fi

#Get the default region and use it or die
REGION=$(gcloud config get-value compute/region)
if [ -z "${REGION}" ]; then
    echo "gcloud cli must be configured with a default region." 1>&2
    echo "run 'gcloud config set compute/region REGION'." 1>&2
    echo "replace 'REGION' with the region name like us-west1." 1>&2
    exit 1;
fi

#Get the current project and use it or die
PROJECT=$(gcloud config get-value project)
if [ -z "${PROJECT}" ]; then
    echo "gcloud cli must be configured with an existing project." 1>&2
    echo "run 'gcloud config set project PROJECTNAME'." 1>&2
    echo "replace 'PROJECTNAME' with the project name like my-demo-project." 1>&2
    exit 1;
fi

CLUSTER_NAME="$(terraform output --state ../../terraform/terraform.tfstate cluster_name)"
gcloud container clusters get-credentials "$CLUSTER_NAME" --region "$REGION"
