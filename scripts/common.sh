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
# "-  Common commands for all scripts                      -"
# "-                                                       -"
# "---------------------------------------------------------"

# Locate the root directory
ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"

# git is required for this tutorial
# https://git-scm.com/book/en/v2/Getting-Started-Installing-Git
command -v git >/dev/null 2>&1 || { \
 echo >&2 "I require git but it's not installed.  Aborting."
 echo >&2 "Refer to: https://git-scm.com/book/en/v2/Getting-Started-Installing-Git"
 exit 1
}

# glcoud is required for this tutorial
# https://cloud.google.com/sdk/install
command -v gcloud >/dev/null 2>&1 || { \
 echo >&2 "I require gcloud but it's not installed.  Aborting."
 echo >&2 "Refer to: https://cloud.google.com/sdk/install"
 exit 1
}

# Make sure kubectl is installed.  If not, refer to:
# https://kubernetes.io/docs/tasks/tools/install-kubectl/
command -v kubectl >/dev/null 2>&1 || { \
 echo >&2 "I require kubectl but it's not installed.  Aborting."
 echo >&2 "Refer to: https://kubernetes.io/docs/tasks/tools/install-kubectl/"
 exit 1
}


# Set false if the ENV var isn't already set/present
IS_CI_ENV=${IS_CI_ENV:-false}


# Ensures gke-tf is installed during CI builds
if [[ "${IS_CI_ENV}" == "true" ]]; then

  # Download a known version of gke-tf
  GKE_TF_PATH="${ROOT}/bin/gke-tf"

  # If gke-tf is not already installed and executable
  if ! [ -x "${GKE_TF_PATH}" ]; then

    # Install a version of gke-tf to ${ROOT}/bin/gke-tf
    # CI runs in a Linux environment
    curl -sLO "https://github.com/GoogleCloudPlatform/gke-terraform-generator/releases/download/0.1-beta.1/gke-tf-linux-amd64"


    # Move to the local bin directory and make executable
    mv "${ROOT}/gke-tf-linux-amd64" "${ROOT}/bin/gke-tf"
    chmod +x "${ROOT}/bin/gke-tf"


  fi
  # Add the local bin directory to the CI $PATH
  export PATH="${ROOT}/bin:$PATH"
fi

# Make sure gke-tf is installed.
command -v gke-tf >/dev/null 2>&1 || { \
 echo >&2 "I require gke-tf but it's not installed.  Aborting."
 exit 1
}

# Set specific ENV variables used by the Google Gloud SDK
PROJECT="$(gcloud config get-value core/project)"
if [[ -z "${PROJECT}" ]]; then
    echo "gcloud cli must be configured with a default project."
    echo "run 'gcloud config set core/project PROJECT'."
    echo "replace 'PROJECT' with the project name."
    exit 1;
fi

REGION="$(gcloud config get-value compute/region)"
if [[ -z "${REGION}" ]]; then
    echo "https://cloud.google.com/compute/docs/regions-zones/changing-default-zone-region"
    echo "gcloud cli must be configured with a default region."
    echo "run 'gcloud config set compute/region REGION'."
    echo "replace 'REGION' with the region name like us-west1."
    exit 1;
fi

ZONE=$(gcloud config get-value compute/zone)
if [[ -z "${ZONE}" ]]; then
    echo "https://cloud.google.com/compute/docs/regions-zones/changing-default-zone-region" 1>&2
    echo "gcloud cli must be configured with a default zone." 1>&2
    echo "run 'gcloud config set compute/zone ZONE'." 1>&2
    echo "replace 'ZONE' with the zone name like us-west1-a." 1>&2
    exit 1;
fi
