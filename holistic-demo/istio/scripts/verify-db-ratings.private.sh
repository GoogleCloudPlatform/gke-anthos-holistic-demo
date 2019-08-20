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

set -e

# Handle different project namings
if [ -z "$GCE_PROJECT" ]; then
  GCE_PROJECT="$PROJECT"
fi

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"

if [ -f "$ROOT/scripts/istio.env" ]; then
  # shellcheck source=scripts/istio.env
  source "$ROOT/scripts/istio.env"
fi

# Set number of stars for review
# Globals:
#   GCE_VM - Name used for GCE VM
#   GCE_PROJECT - Project hosting GCE VM
#   ZONE - Zone of GCE VM
# Arguments:
#   NUM_STARS - The variable to check
# Returns:
#   None
set_ratings() {
  if [[ $1 =~ ^[1-5]$ ]]; then
    COMMAND="mysql -u root --password=password test -e \"update ratings set rating=${1} where reviewid=1\""
    gcloud compute ssh "${GCE_VM}" --project "${GCE_PROJECT}" --zone "${ZONE}" --command "${COMMAND}"
    return 0
  fi

  echo "Passed an invalid value to update the database. Aborting..."
  return 1
}

# Test that changes to db are reflected in web ui
# Globals:
#   None
# Arguments:
#   URL - application URL to test
# Returns:
#   None
test_integration() {
  # Get and store the currently served webpage
  BEFORE="$(curl -s "$1")"
  # Update the MySQL database rating with a two star review to generate a diff
  # proving the MySQL on GCE database is being used by the application
  set_ratings "$2"

  # Get the updated webpage with the updated ratings
  AFTER="$(curl -s "$1")"
  # Check to make sure that changing the rating in the DB generated a diff in the
  # webpage
  if ! diff --suppress-common-lines <(echo "${AFTER}") <(echo "${BEFORE}") \
    > /dev/null
  then
    echo "SUCCESS: Web UI reflects DB change"
    return 0
  else
    if [[ $(echo "${AFTER}" | grep "glyphicon-star" | grep -cv "glyphicon-star-empty") == $((4 + ${2})) ]]; then
      echo "SUCCESS: No changes made to database as new value is same as old value"
      return 0
    fi
    echo "ERROR: DB change wasn't reflected in web UI:"
    diff --suppress-common-lines <(echo "${AFTER}") <(echo "${BEFORE}")
    return 1
  fi
}

# set to jenkins if there is no $USER
USER=$(whoami)
[[ "${USER}" == "root" ]] && export USER=jenkins
echo "user is: $USER"

# Get the IP address and port of the cluster's gateway to run tests against
INGRESS_HOST=$(HTTPS_PROXY=localhost:8888 kubectl -n istio-system get service istio-ingressgateway \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
INGRESS_PORT=$(HTTPS_PROXY=localhost:8888 kubectl -n istio-system get service istio-ingressgateway \
  -o jsonpath='{.spec.ports[?(@.name=="http")].port}')

## Check if port is set or not.
if [ -z "$INGRESS_PORT" ]; then
  GATEWAY_URL="${INGRESS_HOST}"
else
  GATEWAY_URL="${INGRESS_HOST}:${INGRESS_PORT}"
fi

APP_URL="http://${GATEWAY_URL}/productpage"

for x in {1..30}
do
  if [ $x == 30 ]; then
    echo "We have exceeded attempts to validate service..."
    exit 1
  fi

  if test_integration "$APP_URL" "${1}"; then
    exit 0
  fi
  sleep 10
done
