# Installing Anthos Config Management

With Anthos Config Management, you can create a common configuration for all administrative policies that apply to your Kubernetes clusters both on-premises and in the cloud. With the Anthos Config Management Operator deployed in your Kubernetes cluster, it will continuously watch and deploy the appropriate changes so that your desired state is always reflected.

This pattern of deploying an operator inside each cluster that continuously monitors a central `git` repository and implements that desired state is a powerful way to distribute configuration changes and policies across a fleet of GKE clusters.

This demo will show you how to configure a central `git` repository, deploy the Operator to the base GKE cluster, and push changes that the Operator will act on automatically.

## Table of Contents

* [Prerequisites](#prerequisites)
  * [Install Nomos](#install-nomos)
  * [Install kustomize](#install-kustomize)
  * [Install kubectl](#install-kubectl)
* [Initializing the Cloud Source Repository](#initializing-the-cloud-source-repository)
* [Installing Anthos Configuration Management](#installing-anthos-configuration-management)
  * [Deploying the Configuration Management Operator](#deploying-the-configuration-management-operator)
  * [Create the git-creds secret](#create-the-git-creds-secret)
  * [Configuring the Configuration Management Operator](#configuring-the-configuration-management-operator)
  * [Verifying the installation](#verifying-the-installation)
* [Next Steps](#next-steps)
* [Teardown](#teardown)
* [Troubleshooting](#troubleshooting)
* [Relevant Material](#relevant-material)

## Prerequisites

### Deploy the Base Cluster

Deploy the base cluster in the target project as per the instructions in the top-level [README](../README.md#provisioning-the-kubernetes-engine-cluster) and configure your terminal to [access the private cluster](../README.md#accessing-the-private-cluster).

### Install `nomos`

Download the `nomos` CLI tool from [Anthos Configuration Management](https://cloud.google.com/anthos-config-management/docs/nomos-command).

For MacOS, choose `darwin_amd64` and for Cloud Shell choose `linux_amd64`.  After downloading the binary, configure it to be executable:

```console
chmod +x nomos
```

Next, copy the `nomos` binary to a location in your `$PATH`.  On Linux/Cloud Shell/MacOS, you can run:

```console
sudo cp nomos /usr/local/bin/nomos
```

Verify Nomos has been installed into your `$PATH`:

```console
which nomos

/usr/local/bin/nomos
```

### Install Kustomize

On MacOS, you can install `kustomize` with the Homebrew package manager:

```console
brew install kustomize
```

Cloud Shell/Linux:

```console
opsys=linux  # or darwin, or windows

# Get the latest version of kustomize
curl -s https://api.github.com/repos/kubernetes-sigs/kustomize/releases/latest |\
  grep browser_download |\
  grep $opsys |\
  cut -d '"' -f 4 |\
  xargs curl -L -o kustomize
```

Copy `kustomize` to a location in your `$PATH`:

```console
sudo cp kustomize /usr/local/bin/kustomize
```

Make the `kustomize` binary executable:

```console
sudo chmod +x /usr/local/bin/kustomize
```

Verify `kustomize` is working correctly:

```console
which kustomize

/usr/local/bin/kustomize
```

### Install kubectl

In Cloud Shell, `kubectl` is already installed, so you may move on to the next section.  On MacOS:

```console
curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/darwin/amd64/kubectl
```

Make the kubectl binary executable:

```console
chmod +x kubectl
```

Move the binary into a directory in your `$PATH`:

```console
sudo mv kubectl /usr/local/bin/kubectl
```

Test to ensure the version you installed is up-to-date:

```console
kubectl version
```

## Initializing the Cloud Source Repository

Once you have confirmed access to your private cluster, you need to clone a git repository and initialize it using the `nomos` CLI.

Change to the `anthos` directory:

```console
cd anthos
```

Setup the values for your repository ID, Project and account name:

```console
REPO="anthos-demo"
PROJECT=$(gcloud config list --format 'value(core.project)' 2>/dev/null)
ACCOUNT=$(gcloud config list --format 'value(core.account)' 2>/dev/null)
```

Verify these settings are set and correct:

```console
echo $REPO
echo $PROJECT
echo $ACCOUNT
```

Create a cloud source repo:

```console
gcloud source repos create "${REPO}"
```

Clone the repository and change directory into the cloned repo:

```console
gcloud source repos clone "${REPO}"
cd "${REPO}"
```

Initialize the repository using `nomos`:

```console
nomos init
```

Add all new/changed files to the cloned repo, commit with a message, and push the change to the `master` branch:

```console
git add .
git commit -m 'Adding initial files for nomos'
git push
```

This creates the basic directory structure used by the Anthos Configuration Management operator. Specifically, this creates the `./system`, `./cluster`, `./clusteregistry`, and `./namespaces` directories.

## Creating Anthos Configurations

Anthos Config Management keeps your enrolled clusters in sync using kubernetes manifests that are checked into a git source control repository. A kubernetes manifest is a YAML or JSON file that is stored in your repository and contains the same types of configuration details that you can manually apply to a cluster using the kubectl apply command. This [topic](https://cloud.google.com/anthos-config-management/docs/how-to/configs#examples) covers how configs work, how to write them, and how Anthos Config Management applies them to your enrolled clusters.

### Creating a Configuration Manifest

When you create a configuration manifest, you need to decide the best location in the repository and the fields to include.  The location of a configuration manifest in the repository determines which cluster(s) it applies to.

1. Configuration manifests for cluster-scoped objects except for `namespaces` are stored in the `./clusters` directory of the repo.
2. Configuration manifests for `namespaces` and `namespace`-scoped objects are stored in the `./namespaces` directory of the repo.
3. Configuration manifests for Anthos Config Management components are stored in the `./system` directory of the repo.
4. The configuration manifest for the Config Management Operator is not stored directly in the repository and is not synced.

### Example Configuration

One of the simplest examples is to create a `namespace`. In this example, it's named `audit`.  From inside the current repository, copy the files from the example folder into your current folder:

```console
cp -R ../anthos-config-example/namespaces/audit ./namespaces/
```

Add the SSH key materal to the `.gitignore` to prevent getting checked into source control:

```console
cat <<EOT >> .gitignore
anthos-demo-key
anthos-demo-key.pub
config-management-operator.yaml
config-management.yaml
EOT
```

Add all new/changed files to the cloned repo, commit with a message, and push the change to the `master` branch:

```console
git add .
git commit -m 'Adding namespace'
git push
```

## Installing Anthos Configuration Management

### Deploying the Configuration Management Operator

To enroll a cluster in Anthos Config Management, you deploy the Anthos "Operator" manifest, create the `git-creds` `secret`, and finally configure the Operator.  Note that currently, [Pod Security Policies](https://cloud.google.com/kubernetes-engine/docs/how-to/pod-security-policies) are not supported in conjunction with Anthos Config Management.

After ensuring that you meet all the prerequisites, you can deploy the Operator by downloading and applying a YAML manifest.

Download the latest version of the Operator CRD using the following command:

```console
gsutil cp gs://config-management-release/released/latest/config-management-operator.yaml config-management-operator.yaml
```

You may already have `kubectl` with the proxy settings aliased, but you can ensure this is set in the current terminal session:

```console
alias k="HTTPS_PROXY=localhost:8888 kubectl"
```

Apply the manifest which installs the necessary components and starts the Operator:

```console
k apply -f config-management-operator.yaml

customresourcedefinition.apiextensions.k8s.io/configmanagements.addons.sigs.k8s.io created
clusterrolebinding.rbac.authorization.k8s.io/config-management-operator created
clusterrole.rbac.authorization.k8s.io/config-management-operator created
serviceaccount/config-management-operator created
deployment.apps/config-management-operator created
namespace/config-management-system created
```

### Create the `git-creds` `secret`

The Operator needs read-only access to your Git repository (the repo) so it can read the configurations committed to the repository and automatically apply them to your clusters. If credentials are required, they are stored in the `git-creds` Kubernetes `secret` on each enrolled cluster.

You will want to create an SSH keypair to allow the Operator to authenticate to your Git repository. This is necessary if you need to authenticate to the repository in order to clone it or read from it.

The following command creates 4096-bit RSA key. Replace [GIT REPOSITORY USERNAME] and /path/to/[KEYPAIR-FILENAME] with the values you want the Operator to use to authenticate to the repository.

```console
ssh-keygen -t rsa -b 4096 \
 -C "${ACCOUNT}" \
 -N '' \
 -f ./anthos-demo-key
```

Add the following SSH _public_ key to the Cloud Source Repository. You can obtain the contents of the key-file by using a cat command:

```console
cat anthos-demo-key.pub
```

Add the contents of the public SSH Key to your Cloud Source Repository SSH Keys configuration via the UI/Console [https://source.cloud.google.com/user/ssh_keys](https://source.cloud.google.com/user/ssh_keys).  Click `Register SSH Key`, use `anthos-demo` for the key name, copy/paste in the contents of the public key, and click `Register`.

![register-ssh-key](images/register-ssh-key.png?raw=true)

Add the private key to a new `secret` in the cluster:

```console
k create secret generic git-creds \
 --namespace=config-management-system \
 --from-file=ssh=./anthos-demo-key

secret/git-creds created
```

Finally, delete the private key from the local disk (e.g. `rm anthos-demo-key`) or otherwise take appropriate measures to protect it.

### Configuring the Configuration Management Operator

To configure the behavior of the Operator, you create a configuration file for the ConfigManagement [CustomResource](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/), then apply it using `kubectl`.

The `spec` field contains configuration details such as the location of the repository and `secretType` to use. Avoid making changes to configuration values outside the `spec` field.  The following command creates a working Operator configuration manifest:

```console
cat > config-management.yaml <<EOF
apiVersion: addons.sigs.k8s.io/v1alpha1
kind: ConfigManagement
metadata:
  name: config-management
  namespace: config-management-system
spec:
  # clusterName is required and must be unique among all managed clusters
  clusterName: demo-cluster
  git:
    syncRepo: ssh://${ACCOUNT}@source.developers.google.com:2022/p/${PROJECT}/r/${REPO}
    syncBranch: master
    secretType: ssh
    policyDir: "."
EOF
```

Apply the configuration manifest to the cluster:

```console
k apply -f config-management.yaml

configmanagement.addons.sigs.k8s.io/config-management created
```

### Verifying the Installation

You can use the `nomos status` command to check if the Operator is installed successfully and is reporting the correct status. Please note that like `kubectl`, the `nomos` CLI also needs to communicate to the private cluster over the proxy. A similar use of a shell alias can reduce the amount of typing:

```console
alias n="HTTPS_PROXY=localhost:8888 nomos"
n status
```

A valid installation with no problems has a status of `PENDING` or `SYNCED`. An invalid or incomplete installation has a status of `NOT INSTALLED` or `NOT CONFIGURED`. The output also includes any reported errors.

When the Operator is deployed successfully, it runs in a `pod` whose name begins with `config-management-operator`, in the `kube-system` `namespace`. The `pod` may take a few moments to initialize. Verify that the `pod` is running:

```console
k -n kube-system get pods | grep config-management
```

If the `pod` is running, the command's response is similar (but not identical) to the following:

```console
config-management-operator-6f988f5fdd-4r7tr 1/1 Running 0 26s
```

You can also verify that the `config-management-system` `namespace` exists:

```console
k get namespaces | grep 'config-management-system'

config-management-system Active 1m
```

## Next Steps

Return to the top-level [README](../README.md#guided-demos) to begin working on another topic area.

## Teardown

The steps completed above to install and configure a Cloud Source Repository and install the Anthos Configuration Management Operator inside the cluster are necessary prerequisites for several of the other topic areas in this repository.  If you would like to continue working on other topics, refer to the [next steps](#next-steps).

If you are completely finished working with the contents of this repository and want to remove the resources created above, delete the Cloud Source Repository:

```console
gcloud source repos delete ${REPO}

Delete "anthos-demo" in project "my-project-id" (Y/n)?  y

Deleted [anthos-demo].
```

Remove the SSH Public Key by visiting [https://source.cloud.google.com/user/ssh_keys](https://source.cloud.google.com/user/ssh_keys) and deleting the `anthos-demo` SSH Key.

Follow the [teardown steps](../README.md#teardown) in the top-level [README](../README.md#teardown) to remove the cluster and supporting resources.

To remove the shell alias `nomos`, run:

```console
unalias n
```

## Troubleshooting

### Detecting Invalid Configurations

It is possible to have an invalid configuration that isn't detected right away, such as a missing or invalid `git-creds` `secret`. For troubleshooting steps, refer to the [Valid but incorrect ConfigManagement object](https://cloud.google.com/anthos-config-management/docs/how-to/installing#configmanagement-status-fields) section in the official troubleshooting documentation.

## Relevant Material

* [Anthos Configuration Management Overview](https://cloud.google.com/anthos-config-management/docs)
* [Installing Anthos Configuration Management](https://cloud.google.com/anthos-config-management/docs/how-to/installing)

Note, **this is not an officially supported Google product**
