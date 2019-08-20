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

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"

source "$ROOT/scripts/istio.env"
ISTIO_DIR="$ROOT/istio-${ISTIO_VERSION}"
if [[ ! -d "$ISTIO_DIR" ]]; then
  if [[ "$(uname -s)" == "Linux" ]]; then
    export OS_TYPE="linux"
  elif [[ "$(uname -s)" == "Darwin" ]]; then
    export OS_TYPE="osx"
  fi

  (cd "$ROOT";
    curl -L --remote-name https://github.com/istio/istio/releases/download/$ISTIO_VERSION/istio-$ISTIO_VERSION-$OS_TYPE.tar.gz
    # extract istio
    tar -xzf "$ROOT/istio-$ISTIO_VERSION-$OS_TYPE.tar.gz"

    # remove istio zip
    rm "$ROOT/istio-$ISTIO_VERSION-$OS_TYPE.tar.gz"
  )
fi