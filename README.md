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
  * [Validation](#validation)
* [Guided Demos](#guided-demos)
* [Tear down](#tear-down)
<!-- TOC -->

## Introduction

This demo guides you through deploying a private GKE cluster and providing a base platform for exploring the several subject areas with hands-on guidance.

You should first configure Anthos Configuration Management inside your Cluster:

* [Anthos Configuration Management](#guided-demos) - Learn how to centrally manage your fleet of GKE Clusters using a "git-ops" workflow.

After completing the [Anthos Configuration Management](#guided-demos) configuration, you can explore the following topics in any order you choose:

1. [Binary Authorization](#guided-demos) - Learn how to enforce which containers run inside your GKE Cluster.
1. [Role-Based Access Control](#guided-demos) - Understand how RBAC can be used to grant specific permissions to users and groups accessing the Kubernetes API.
1. [Logging with Stackdriver](#guided-demos) - Learn how GKE Clusters send logs and metrics to Stackdriver and how to export those to Google Cloud Storage (GCS) Buckets for long term storage and BigQuery datasets for analysis.
1. [Monitoring with Stackdriver](#guided-demos) - Learn how GKE Clusters send metrics to Stackdriver to monitor your cluster and container application performance.

Additional topics will be added as they are integrated into this demo structure, so check back often.

## Architecture

The `gke-tf` CLI tool in combination with the `gke-tf-demo.yaml` configuration file will generate the necessary `terraform` infrastructure-as-code in the `./terraform` directory.  Within the GCP project that you have `Project Owner` permissions, the generated `terraform` will be used to manage the lifecycle of all the required resources.  This includes the VPC networks, firewall rules, subnets, service accounts, IAM roles, GCE instances, and the GKE Cluster.

Note that this regional GKE cluster is configured as a private GKE cluster, so a dedicated "bastion" host GCE instance is provided to protect the GKE API from the open Internet.  Accessing the GKE API requires first running an SSH tunnel to the bastion host while forwarding a local port (`8888`).  The GKE worker nodes have egress access via a Cloud NAT instance to be able to pull container images and other assets as needed.

## Prerequisites

### Run Demo in a Google Cloud Shell

Click the button below to run the demo in a [Google Cloud Shell](https://cloud.google.com/shell/docs/).

[![Open in Cloud Shell](http://gstatic.com/cloudssh/images/open-btn.svg)](https://console.cloud.google.com/cloudshell/open?cloudshell_git_repo=https://github.com/GoogleCloudPlatform/gke-anthos-holistic-demo.git&amp;cloudshell_image=gcr.io/graphite-cloud-shell-images/terraform:latest&amp;cloudshell_tutorial=README.md)

All the tools for the demo are installed. When using Cloud Shell execute the following
command in order to setup gcloud cli. When executing this command please setup your region
and zone.

```console
gcloud init
```

### Tools

1. [gke-tf](https://github.com/GoogleCloudPlatform/gke-terraform-generator) for your architecture in your `$PATH`
1. [Terraform >= 0.12.3](https://www.terraform.io/downloads.html)
1. [Google Cloud SDK version >= 244.0.0](https://cloud.google.com/sdk/docs/downloads-versioned-archives)
1. [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) matching the latest GKE version.
1. `bash` or `bash` compatible shell
1. A Google Cloud Platform project where you have `Project Owner` permissions to create VPC networks, service accounts, IAM Roles, GKE clusters, and more.

#### Install Cloud SDK

The Google Cloud SDK is used to interact with your GCP resources.
[Installation instructions](https://cloud.google.com/sdk/downloads) for multiple platforms are available online.

#### Install `gke-tf`

The `gke-tf` CLI is used for generating the necessary Terraform infrastructure-as-code source files to build the VPC, networks, service accounts, IAM roles, and GKE cluster from a single configuration YAML file.  [Installation instructions](https://github.com/GoogleCloudPlatform/gke-terraform-generator/).

#### Install `kubectl` CLI

The kubectl CLI is used to interteract with both Kubernetes Engine and kubernetes in general.
[Installation instructions](https://cloud.google.com/kubernetes-engine/docs/quickstart)
for multiple platforms are available online.

#### Install `terraform`

Terraform is used to automate the manipulation of cloud infrastructure. Its
[installation instructions](https://www.terraform.io/intro/getting-started/install.html) are also available online.

## Deployment

The steps below will walk you through using terraform to deploy a Kubernetes Engine cluster that you will then use for installing test users, applications and RBAC roles.

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

### Validation

When Terraform has successfully created the cluster, you will see several generated outputs:

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

To access this private GKE cluster, first run the following command to obtain a valid set of Kubernetes credentials:

```console
$(terraform output get_credentials)

Fetching cluster endpoint and auth data.
kubeconfig entry generated for demo-cluster.
```

Notice that the `gcloud container clusters get-credentials` command specified the `--internal-ip` flag to use the private GKE Control Plane IP.

Next, open up a **second** terminal and run the following command to create an SSH tunnel through

```console
$(terraform output bastion_ssh)

...snip...
permitted by applicable law.
myusername@demo-cluster-bastion:~$
```

This terminal will create an SSH session and also forward the local port `8888` to the local port `8888` on the bastion host.  If this SSH session disconnects, you will need to re-run it to be able to reach the GKE API.

Back on the first terminal, run the following command to access the GKE cluster over the SSH proxy tunnel:

```console
echo $(terraform output bastion_kubectl)
HTTPS_PROXY=localhost:8888 kubectl get pods --all-namespaces

NAMESPACE     NAME                                                        READY   STATUS    RESTARTS   AGE
kube-system   calico-node-f49fd                                           2/2     Running   0          25m
kube-system   calico-node-sj8pp                                           2/2     Running   0          25m
kube-system   calico-node-tw84c                                           2/2     Running   0          26mZ

...snip...

kube-system   prometheus-to-sd-4xb67                                      1/1     Running   0          27m
kube-system   prometheus-to-sd-fnd2l                                      1/1     Running   0          27m
kube-system   stackdriver-metadata-agent-cluster-level-594ff5c995-htszq   1/1     Running   3          28m
```

You may wish to simplify the amount of typing by "aliasing" this command to `k`:

```console
alias k="HTTPS_PROXY=localhost:8888 kubectl"
k get pods --all-namespaces
```

From this terminal session, in place of `kubectl`, you can use `k` to be the shortcut for running `HTTPS_PROXY=localhost:8888 kubectl`.  Now that you have successfully accessed your private GKE cluster, you can proceed with the next section.

## Guided Demos

After following the guidance in the [Prerequisites](#prerequisites) section and successfully creating the base GKE Cluster and supporting resources in the [Deployment] section, you should proceed first to configure Anthos Configuration Management in your cluster.

1. [Anthos Configuration Management](anthos/README.md) - Learn how to centrally manage your fleet of GKE Clusters using a "git-ops" workflow.

After completing the [Anthos Configuration Management](#guided-demos) configuration, you can explore the following topics in any order you choose:

1. [Binary Authorization](holistic-demo/binary-auth/README.md) - Learn how to enforce which containers run inside your GKE Cluster.
1. [Role-Based Access Control](holistic-demo/rbac/README.md) - Understand how RBAC can be used to grant specific permissions to users and groups accessing the Kubernetes API.
1. [Logging with Stackdriver](holistic-demo/logging-sinks/README.md) - Learn how GKE Clusters send logs and metrics to Stackdriver and how to export those to Google Cloud Storage (GCS) Buckets for long term storage and BigQuery datasets for analysis.
1. [Monitoring with Stackdriver](holistic-demo/monitoring/README.md) - Learn how GKE Clusters send metrics to Stackdriver to monitor your cluster and container application performance.

## Tear down

Log out of the bastion host by typing `exit` in that terminal sessions and run the following to destroy the environment via Terraform in the current terminal:

```console
cd terraform # if not already in this directory
terraform destroy
```

```console
...snip...
google_compute_network.demo-network: Still destroying... (ID: demo-netowrk, 10s elapsed)
google_compute_network.demo-network: Still destroying... (ID: demo-netowrk, 20s elapsed)
google_compute_network.demo-network: Destruction complete after 25s

Destroy complete! Resources: 20 destroyed.
```

**This is not an officially supported Google product**
