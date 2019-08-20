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

export GCP_OPTS="--region ${REGION} --project ${ISTIO_PROJECT}"
export SERVICE_NAMESPACE=vm
(
  cd "$ISTIO_DIR"
  "$ISTIO_DIR/install/tools/setupMeshEx.sh" \
    generateClusterEnv "${ISTIO_CLUSTER}"
)

# # Ensure that mTLS is enabled
if [[ "${ISTIO_AUTH_POLICY}" == "MUTUAL_TLS" ]] ; then
  sed -i'' -e "s/CONTROL_PLANE_AUTH_POLICY=NONE/CONTROL_PLANE_AUTH_POLICY=${ISTIO_AUTH_POLICY}/g" "$ISTIO_DIR/cluster.env"
fi

# Generate the DNS configuration necessary to have the GCE VM join the mesh.
(
  cd $ISTIO_DIR
  "$ISTIO_DIR/install/tools/setupMeshEx.sh" generateDnsmasq
)

# Create the keys for mTLS
(
  cd $ISTIO_DIR
  "$ISTIO_DIR/install/tools/setupMeshEx.sh" machineCerts default vm all
)

# # Re-export the GCP_OPTS to switch the project to the project where the VM
# # resides
export GCP_OPTS="--zone ${ZONE} --project ${GCE_PROJECT}"
# # Setup the Istio service proxy and service on the GCE VM
(
  cd "$ISTIO_DIR"
  "$ISTIO_DIR/install/tools/setupMeshEx.sh" gceMachineSetup "${GCE_VM}"
)