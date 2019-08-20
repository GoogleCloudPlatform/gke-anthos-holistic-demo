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

# Install MySQL and load the data for the MySQL service

set -e

# Tested with latest mariadb-server on apt-get, which was 1:10.3.15-1 at the time.
sudo apt-get update && sudo apt-get install --no-install-recommends -y mariadb-server=1:10.3.15-1

# Give all privileges to all databases to the root user on localhost and then
# reload the privilege grants
sudo mysql \
  -e "grant all privileges on *.* to 'root'@'localhost' identified by 'password'; flush privileges"

# Grab the sample database data from GitHub and load it
# Of course, it goes without saying that you should not use "password" as your
# password in real life.
curl https://raw.githubusercontent.com/istio/istio/master/samples/bookinfo/src/mysql/mysqldb-init.sql \
  | mysql -u root --password=password -h 127.0.0.1

# Configure Envoy to integrate with the GKE Istio mesh
sudo sed -i -e "\$aISTIO_INBOUND_PORTS=3306" /var/lib/istio/envoy/sidecar.env
sudo sed -i -e "\$aISTIO_SERVICE=mysqldb" /var/lib/istio/envoy/sidecar.env
sudo sed -i -e "\$aISTIO_NAMESPACE=vm" /var/lib/istio/envoy/sidecar.env

# https://manpages.debian.org/jessie/systemd/systemctl.1.en.html
sudo systemctl restart istio

