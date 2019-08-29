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
# "-  Validation script checks if the vault cluster        -"
# "-  deployed successfully.                               -"
# "-                                                       -"
# "---------------------------------------------------------"

# bash "strict-mode", fail immediately if there is a problem
set -o nounset
set -o pipefail


shopt -s expand_aliases
OUTPUT="kube-system"

# # Locate the root directory
ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
source "$ROOT/scripts/common.sh"

# Validate get-creds to get access to the GKE
cd "$ROOT/terraform" || exit;
echo "$(terraform output get_credentials)\n"
$(terraform output get_credentials)

# Run bastion in a second terminal for port forwarding
echo "Validating bastion_ssh and aliasing"
$(terraform output bastion_ssh) -f tail -f  /dev/null

sleep 5
# Alias kubectl for port forwarding, and test the command using k get pods
alias k="HTTPS_PROXY=localhost:8888 kubectl" &> /dev/null || exit 1
k get pods --all-namespaces | grep "$OUTPUT" &> /dev/null || exit 1

echo "Port forwarding to bastion successful"
