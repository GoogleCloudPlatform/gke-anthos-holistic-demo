# Holistic View of Anthos on Google Kubernetes Engine (GKE)

## Table of Contents

<!-- TOC -->
* [Introduction](#introduction)
* [Architecture](#architecture)
* [Prerequisites](#prerequisites)
* [Deployment](#deployment)
  * [Authenticate gcloud](#authenticate-gcloud)
  * [Setup this project](#setup-this-project)
  * [Cluster Deployment](#cluster-deployment)
  * [Provisioning the Kubernetes Engine Cluster](#provisioning-the-kubernetes-engine-cluster)
  * [Accessing the Private Cluster](#accessing-the-private-cluster)
* [Guided Demos](#guided-demos)
* [Teardown](#teardown)
* [Troubleshooting](#troubleshooting)
<!-- TOC -->

## Introduction

This repository guides you through deploying a private GKE cluster and provides a base platform for hands-on exploration of several GKE related topics which leverage or integrate with that infrastructure.  After completing the exercises in all topic areas, you will have a deeper understanding of several core components of GKE and GCP as configured in an enterprise environment.

To follow this guide successfully:

1. Install the prerequisite [tools](#prerequisites).
1. [Deploy](#deployment) the base GKE Cluster in a project of your choosing.
1. Proceed to the [guided demos](#guided-demos) section to learn more about each topic area via hands-on instruction.

Additional topics will be added as they are integrated into this demo structure, so check back often.

Note, when you clone this repo, specify --recursive to pull down dependencies (ie, submodules).

## Architecture

The `gke-tf` CLI tool in combination with the `gke-tf-demo.yaml` configuration file will generate the necessary `terraform` infrastructure-as-code in the `./terraform` directory.  Within the GCP project that you have `Project Owner` permissions, the generated `terraform` will be used to manage the lifecycle of all the required resources.  This includes the VPC networks, firewall rules, subnets, service accounts, IAM roles, GCE instances, and the GKE Cluster.

Note that this regional GKE cluster is configured as a private GKE cluster, so a dedicated "bastion" host GCE instance is provided to protect the GKE API from the open Internet.  Accessing the GKE API requires first running an SSH tunnel to the bastion host while forwarding a local port (`8888`).  The GKE worker nodes have egress access via a Cloud NAT instance to be able to pull container images and other assets as needed.

## Prerequisites

### Run Demo in a Google Cloud Shell

Click the button below to run the demo in a [Google Cloud Shell](https://cloud.google.com/shell/docs/).

[![Open in Cloud Shell](http://gstatic.com/cloudssh/images/open-btn.svg)](https://console.cloud.google.com/cloudshell/open?cloudshell_git_repo=https://github.com/GoogleCloudPlatform/gke-anthos-holistic-demo.git&amp;cloudshell_image=gcr.io/graphite-cloud-shell-images/terraform:latest&amp;cloudshell_tutorial=README.md)

When using Cloud Shell execute the following
command in order to setup gcloud cli. When executing this command please setup your region
and zone.

```console
gcloud init
```

#### Tools Needed in Cloud Shell

1. [gke-tf](https://github.com/GoogleCloudPlatform/gke-terraform-generator) for your architecture in your `$PATH`

Move on to the [Tools](#tools) section for installation instructions.

### Run Demo on a Local Workstation

#### Tools Needed

1. A Google Cloud Platform project where you have `Project Owner` permissions to create VPC networks, service accounts, IAM Roles, GKE clusters, and more.
1. `bash` or `bash` compatible shell
1. [Google Cloud SDK version >= 244.0.0](https://cloud.google.com/sdk/docs/downloads-versioned-archives)
1. [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) matching the latest GKE version.
1. [gke-tf](https://github.com/GoogleCloudPlatform/gke-terraform-generator) for your architecture in your `$PATH`
1. [Terraform >= 0.12.3](https://www.terraform.io/downloads.html)

### Tools

#### Install Cloud SDK

The Google Cloud SDK is used to interact with your GCP resources.
[Installation instructions](https://cloud.google.com/sdk/downloads) for multiple platforms are available online.

#### Install `kubectl` CLI

The kubectl CLI is used to interteract with both Kubernetes Engine and kubernetes in general.
[Installation instructions](https://cloud.google.com/kubernetes-engine/docs/quickstart)
for multiple platforms are available online. Ensure that you download a version of `kubectl` that is equal to or newer than the version of the GKE cluster you are accessing.

#### Install `gke-tf`

The `gke-tf` CLI is used for generating the necessary Terraform infrastructure-as-code source files to build the VPC, networks, service accounts, IAM roles, and GKE cluster from a single configuration YAML file.  [Installation instructions](https://github.com/GoogleCloudPlatform/gke-terraform-generator/).

#### Install `terraform`

Terraform is used to automate the manipulation of cloud infrastructure. Its
[installation instructions](https://www.terraform.io/intro/getting-started/install.html) are also available online.

### Authenticate gcloud

Prior to running this demo, ensure you have authenticated your gcloud client by running the following command:

```console
gcloud auth application-default login
```

Also, confirm the `gcloud` configuration is properly pointing at your desired project.  Run `gcloud config list` and make sure that `compute/zone`, `compute/region` and `core/project` are populated with values that work for you. You can set their values with the following commands:

```console
# Where the region is us-east1
gcloud config set compute/region us-east1

Updated property [compute/region].
```

```console
# Where the zone inside the region is us-east1-c
gcloud config set compute/zone us-east1-c

Updated property [compute/zone].
```

```console
# Where the project id is my-project-id
gcloud config set project my-project-id

Updated property [core/project].
```

## Deployment

The steps below will walk you through using terraform to deploy a Kubernetes Engine cluster that you will then use for installing test users, applications and RBAC roles.

### Setup this project

The Terraform generated by `gke-tf` will enable the following Google Cloud Service APIs in the target project:

* `cloudresourcemanager.googleapis.com`
* `container.googleapis.com`
* `compute.googleapis.com`
* `iam.googleapis.com`
* `logging.googleapis.com`
* `monitoring.googleapis.com`

### Provisioning the Kubernetes Engine Cluster

Review the `gke-tf-demo.yaml` file in the root of this repository for an understanding of how the GKE Cluster will be configured.  You may wish to edit the `region:` field to one that is geographically closer to your location.  The default is `us-central1` unless changed.

With `gke-tf` in your `$PATH`, generate the Terraform necessary to build the cluster for this demo.  The command below will send the generated Terraform files to the `terraform` directory inside this repository and use the `gke-tf-demo.yaml` as the cluster configuration file input.  The GCP project is passed to this command as well.

```console
export PROJECT="$(gcloud config list project --format='value(core.project)')"
gke-tf gen -d ./terraform -f gke-tf-demo.yaml -o -p ${PROJECT}

I0719 16:05:08.219900   57205 gen.go:78]
+-------------------------------------------------------------------+
|    __.--/)  .-~~   ~~>>>>>>>>   .-.    gke-tf                     |
|   (._\~  \ (        ~~>>>>>>>>.~.-'                               |
|     -~}   \_~-,    )~~>>>>>>>' /                                  |
|       {     ~/    /~~~~~~. _.-~                                   |
|        ~.(   '--~~/      /~ ~.                                    |
|   .--~~~~_\  \--~(   -.-~~-.  \                                   |
|   '''-'~~ /  /    ~-.  \ .--~ /                                   |
|        (((_.'    (((__.' '''-'                                    |
+-------------------------------------------------------------------+
I0719 16:05:08.225777   57205 gen.go:91] Creating terraform for your GKE cluster demo-cluster.
I0719 16:05:08.227777   57205 templates.go:150] Created terraform file: main.tf
I0719 16:05:08.228081   57205 templates.go:150] Created terraform file: network.tf
I0719 16:05:08.228309   57205 templates.go:150] Created terraform file: outputs.tf
I0719 16:05:08.228507   57205 templates.go:150] Created terraform file: variables.tf
I0719 16:05:08.228520   57205 templates.go:153] Finished creating terraform files in: ./terraform
```

Review the generated Terraform files in the `terraform` directory to understand what will be built inside your GCP project.  If anything needs modifying, edit the `gke-tf-demo.yaml` and re-run the `gke-tf gen` command above.  The newly generated Terraform files will reflect your changes.  You are then ready to proceed to using Terraform to build the cluster and supporting resources.

Next, apply the terraform configuration with:

```console
cd terraform
terraform init
terraform plan
terraform apply
```

Enter `yes` to deploy the environment when prompted after running `terraform apply`.  This will take several minutes to build all the necessary GCP resources and GKE Cluster.

### Accessing the Private Cluster

When Terraform has finished creating the cluster, you will see several generated outputs that will help you to access the private control plane:

```console
Apply complete! Resources: 20 added, 0 changed, 0 destroyed.

Outputs:

bastion_kubectl = HTTPS_PROXY=localhost:8888 kubectl get pods --all-namespaces
bastion_ssh = gcloud compute ssh demo-cluster-bastion --project my-project-id --zone us-central1-a -- -L8888:127.0.0.1:8888
cluster_ca_certificate = <sensitive>
cluster_endpoint = 172.16.0.18
cluster_location = us-central1
cluster_name = demo-cluster
get_credentials = gcloud container clusters get-credentials --project my-project-id --region us-central1 --internal-ip demo-cluster
```

In addition to the GKE cluster, a small GCE instance known as a "bastion host" was also provisioned which supports SSH "tunneling and HTTP proxying" to allow remote API Server access in a more secure manner. To access the GKE cluster, first run the following command to obtain a valid set of Kubernetes credentials:

```console
echo $(terraform output get_credentials)
$(terraform output get_credentials)

Fetching cluster endpoint and auth data.
kubeconfig entry generated for demo-cluster.
```

Notice that the `gcloud container clusters get-credentials` command specified the `--internal-ip` flag to use the private GKE Control Plane IP.

Next, open up a **second** terminal in the `./terraform` directory and run the following command:

```console
$(terraform output bastion_ssh)

...snip...
permitted by applicable law.
myusername@demo-cluster-bastion:~$
```

With this "SSH Tunnel" running and forwarding port `8888`, any web traffic sent to our `localhost:8888` will be sent down the tunnel and connect to the [tiny proxy](https://tinyproxy.github.io/) instance running on the `demo-cluster-bastion` host listening on `localhost:8888`.

If this SSH session disconnects, you will need to re-run the above command to reconnect and reach the GKE API.

Because `kubectl` honors the `HTTPS_PROXY` environment variable, this means that our `kubectl` commands can be sent securely over the SSH tunnel and through the HTTP(S) proxy and reach the GKE control plane inside that VPC network via its private IP. While it's possible to run `export HTTPS_PROXY=localhost:8888` in the current session, that environment variable is honored by other applications, which might not be desirable.  For the duration of this terminal session, setting a simple shell alias will make all `kubectl` commands use the SSH tunnel's HTTP proxy:

```console
alias k="HTTPS_PROXY=localhost:8888 kubectl"
```

Now, every time `k` is used within this terminal session, the shell will silently replace it with `HTTPS_PROXY=localhost:8888 kubectl`, and the connection will work as expected.

```console
k get pods --all-namespaces

NAMESPACE     NAME                                                        READY   STATUS    RESTARTS   AGE
kube-system   calico-node-f49fd                                           2/2     Running   0          25m
kube-system   calico-node-sj8pp                                           2/2     Running   0          25m
kube-system   calico-node-tw84c                                           2/2     Running   0          26mZ
...snip...
kube-system   prometheus-to-sd-4xb67                                      1/1     Running   0          27m
kube-system   prometheus-to-sd-fnd2l                                      1/1     Running   0          27m
kube-system   stackdriver-metadata-agent-cluster-level-594ff5c995-htszq   1/1     Running   3          28m
```

## Guided Demos

After following the guidance in the [Prerequisites](#prerequisites) section and successfully creating the base GKE Cluster and supporting resources in the [Deployment](#deployment) section, you will first want to configure Anthos Configuration Management in your cluster.

1. [Anthos Configuration Management](anthos/README.md) - Learn how to centrally manage your fleet of GKE Clusters using a "git-ops" workflow.

After completing the [Anthos Configuration Management](#guided-demos) configuration, you can explore the following topics in any order you choose:

* [Binary Authorization](holistic-demo/binary-auth/README.md) - Learn how to enforce which containers run inside your GKE Cluster.
* [Role-Based Access Control](holistic-demo/rbac/README.md) - Understand how RBAC can be used to grant specific permissions to users and groups accessing the Kubernetes API.
* [Logging with Stackdriver](holistic-demo/logging-sinks/README.md) - Learn how GKE Clusters send logs and metrics to Stackdriver and how to export those to Google Cloud Storage (GCS) Buckets for long term storage and BigQuery datasets for analysis.
* [Monitoring with Stackdriver](holistic-demo/monitoring/README.md) - Learn how GKE Clusters send metrics to Stackdriver to monitor your cluster and container application performance.

## Teardown

This teardown step will remove the base GKE cluster and supporting resources that each topic area uses.  Only perform the following procedures when you have completed all the desired topics and wish to fully remove all demo resources.

If you have completed any of the [guided-demos](#guided-demos), be sure to follow the __Teardown__ section of each one to fully remove the resources that were created.  After those are removed, you can remove the base cluster and its supported resources.

Log out of the bastion host by typing `exit` in that terminal sessions and run the following to destroy the environment via Terraform in the current terminal from the base of the repository:

```console
cd terraform
terraform destroy
```

```console
...snip...
google_compute_network.demo-network: Still destroying... (ID: demo-network, 10s elapsed)
google_compute_network.demo-network: Still destroying... (ID: demo-network, 20s elapsed)
google_compute_network.demo-network: Destruction complete after 25s

Destroy complete! Resources: 20 destroyed.
```

If you have already followed the [Teardown](anthos/README.md#teardown) steps to delete the Cloud Source Repository, you can delete the local `anthos-demo` repository folder:

```console
rm -rf anthos/anthos-demo
```

All resources should now be fully removed.

## Troubleshooting

### Restarting a Failed SSH Tunnel

During the `make create` command, the `gcloud compute ssh` command is run to create the SSH tunnel, forward the local port `8888`, and background the session.  If it stops running and `kubectl` commands are no longer working, rerun it:

```console
`echo $(terraform output --state=../../terraform/terraform.tfstate bastion_ssh) -f tail -f /dev/null`
```

### Stopping the SSH Tunnel that is Running in the Background

Because `gcloud` leverages the host's SSH client binary to run SSH sessions, the process name may vary.  The most reliable method is to find the `process id` of the SSH session and run `kill <pid>` or `pkill <processname>`

```console
ps -ef | grep "ssh.*L8888:127.0.0.1:8888" | grep -v grep

579761 83734     1   0  9:53AM ??         0:00.02 /usr/local/bin/gnubby-ssh -t -i /Users/myuser/.ssh/google_compute_engine -o CheckHostIP=no -o HostKeyAlias=compute.192NNNNNNNN -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=/Users/myuser/.ssh/google_compute_known_hosts myuser@bas.tion.ip.addr -L8888:127.0.0.1:8888 -f tail -f /dev/null /dev/null
```

In this case, running `pkill gnubby-ssh` or `kill 83734` would end this SSH session.

### The install script fails with a `Permission denied` when running Terraform

The credentials that Terraform is using do not provide the necessary permissions to create resources in the selected projects. Ensure that the account listed in `gcloud config list` has necessary permissions to create resources. If it does, regenerate the application default credentials using `gcloud auth application-default login`.

Note, **this is not an officially supported Google product**.
