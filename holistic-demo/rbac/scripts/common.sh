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

# bash "strict-mode", fail immediately if there is a problem

set -euo pipefail

auth_sa() {
  local sa=$1; shift;
  SA_EMAIL="$(terraform output --state=./terraform/terraform.tfstate ${sa}_sa_name)"
  terraform output --state="terraform/terraform.tfstate" "${sa}_sa_key" | gcloud auth activate-service-account --key-file=- "${SA_EMAIL}" 2> /dev/null
  $(terraform output --state="../../terraform/terraform.tfstate" get_credentials)
}

owner() {
  local command=$1; shift;
  # Switch kubectl auth to Owner
  auth_sa "owner"
  # shellcheck disable=SC2005
  echo "$(HTTPS_PROXY=localhost:8888 ${command} 2>&1)"
}

admin() {
  local command=$1; shift;
  # Switch kubectl auth to Admin
  auth_sa "admin"
  # shellcheck disable=SC2005
  echo "$(HTTPS_PROXY=localhost:8888 ${command})"
}

auditor() {
  local command=$1; shift;
  # Switch kubectl auth to Auditor
  auth_sa "auditor"
  # shellcheck disable=SC2005
  echo "$(HTTPS_PROXY=localhost:8888 ${command} 2>&1)"
}

check_ssh_tunnel() {
  echo -n "Checking if the SSH tunnel is running..."
  if [[ -z "$(netstat -nat | grep '8888.*LISTEN')" ]]; then
    # Obtain the foreground command
    TF_OUTPUT="$(terraform output --state=${ROOT}/../../terraform/terraform.tfstate bastion_ssh)"
    # Run via a continuous running background command
    ${TF_OUTPUT} -f tail -f /dev/null 2>&1 /dev/null
    echo "started."
  else
    echo "running."
  fi
}
