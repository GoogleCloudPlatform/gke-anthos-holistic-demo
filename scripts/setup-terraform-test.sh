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

set -o errexit
set -o nounset
set -o pipefail

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
# shellcheck source=scripts/common.sh
source "$ROOT"/scripts/common.sh

rm "$ROOT/terraform.tfvars"

# Generate the variables to be used by Terraform
# shellcheck source=scripts/generate-tfvars.sh
source "$ROOT/scripts/generate-tfvars.sh"

file_paths=( 
	    "$ROOT/holistic-demo/logging-sinks/terraform"
	    "$ROOT/holistic-demo/rbac/terraform"
	   )

for i in "${file_paths[@]}"
do
   :
	# Initialize and run Terraform
	echo "Setting up test for ${i}"
	echo "Running terraform init and terraform plan"
	(cd "${i}"; terraform init -input=false)
	(cd "${i}"; terraform plan -input=false -var-file="$ROOT/terraform.tfvars")
done
