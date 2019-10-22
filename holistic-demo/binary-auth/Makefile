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
# Make will use bash instead of sh
SHELL := /usr/bin/env bash

ROOT := ${CURDIR}

# all is the first target in the file so it will get picked up when you just
#   run 'make' on its own
all:
	@echo "Run 'make validate', or 'make lint'"

.PHONY: lint
lint: check_shell check_shebangs check_python check_golang check_terraform \
	check_docker check_base_files check_headers check_trailing_whitespace
# create/delete/validate is for CICD
.PHONY: validate
validate:
	@source $(ROOT)/scripts/validate.sh
