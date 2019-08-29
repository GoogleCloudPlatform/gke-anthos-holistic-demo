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
DATASET_OUTPUT="gke_logs_dataset"
STORAGE_BUCKET="gs://stackdriver-gke-logging-bucket"

# # Locate the root directory
ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
source "$ROOT/scripts/common.sh"



# Check the creation of bq dataset
echo "Validating bigquery dataset"
bq ls --format=pretty | grep "$DATASET_OUTPUT" &> /dev/null || exit 1
echo "Bq dataset exists"

# Check the creation of storage bucket
echo "Validating storage bucket"
gsutil ls | grep "$STORAGE_BUCKET" &> /dev/null || exit 1
echo "Storage bucket exists"
