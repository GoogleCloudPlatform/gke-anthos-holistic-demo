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
# "-  Validation script checks if the GKE cluster and the  -"
# "-  necessary APIs were deployed successfully.           -"
# "-                                                       -"
# "---------------------------------------------------------"

# Do no set exit on error, since the rollout status command may fail
set -o nounset
set -o pipefail

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT=""
CLUSTER_NAME=""
ZONE=""

# shellcheck source=./common.sh
source "$ROOT/common.sh"

# Verify BinAuthZ policy is available/enabled
if gcloud beta container binauthz policy export | grep "defaultAdmissionRule" > /dev/null; then
  echo "Validation Passed: a working BinAuthZ policy was available"
else
  echo "Validation Failed: a working BinAuthZ policy was NOT available"
  exit 1
fi

# Verify Container Analysis API is available/enabled
if curl -s -H "Authorization: Bearer $(gcloud auth print-access-token)" "https://containeranalysis.googleapis.com/v1beta1/projects/${PROJECT}/notes/" > /dev/null; then
  echo "Validation Passed: the Container Analysis API was available"
else
  echo "Validation Failed: the Container Analysis API was NOT available"
  exit 1
fi
