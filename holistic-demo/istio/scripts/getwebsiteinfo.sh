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

# Get the information about the gateway used by Istio to expose the BookInfo
# application
INGRESS_HOST=$(kubectl -n istio-system get service istio-ingressgateway -o \
  jsonpath='{.status.loadBalancer.ingress[0].ip}')
INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o \
  jsonpath='{.spec.ports[?(@.name=="http")].port}')

# Check if port is set or not.
if [ -z "$INGRESS_PORT" ]; then
  GATEWAY_URL="${INGRESS_HOST}"
else
  GATEWAY_URL="${INGRESS_HOST}:${INGRESS_PORT}"
fi

echo "You can view the service at http://${GATEWAY_URL}/productpage"