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

# "---------------------------------------------------------"
# "-                                                       -"
# "-  Teardown removes all GKE clusters                    -"
# "-                                                       -"
# "---------------------------------------------------------"

# Do not set errexit as it makes partial deletes impossible
set -o nounset
set -o pipefail

# Locate the root directory
ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"

# shellcheck source=scripts/common.sh
source "$ROOT/scripts/common.sh"

# Tear down Terraform-managed resources and remove generated tfvars
cd "$ROOT/terraform" || exit;
# Ignore warnings for outputs that no longer exist. See: https://github.com/hashicorp/terraform/issues/17655
export TF_WARN_OUTPUT_ERRORS=1;
# Perform the destroy
terraform destroy -input=false -auto-approve
# Remove the tfvars file generated during "make create"
rm -f "$ROOT/terraform/terraform.tfvars"

# Remove the gke-tf binary
rm -f "$ROOT/bin/gke-tf"
