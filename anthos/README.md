Installing Anthos Config Management

The Config Management Operator is a controller that manages Anthos Config Management in a Kubernetes cluster. Follow these steps to install and configure the Operator in each cluster you want to manage using Anthos Config Management.

With Anthos Config Management, you can create a common configuration for all administrative policies that apply to your Kubernetes clusters both on-premises and in the cloud. Anthos Config Management evaluates changes and rolls them out to all clusters so that your desired state is always reflected.

Table of Contents
=================

* [Prerequisites](#prerequisites)
   * [Install Nomos command](#install-nomos-command)
   * [Install kustomize:](#install-kustomize)
   * [Install kubectl on macOS](#install-kubectl-on-macos)
* [Setting up access to the private cluster:](#setting-up-access-to-the-private-cluster)
* [Initializing your repo:](#initializing-your-repo)
* [Installing Anthos Config Management for the private cluster](#installing-anthos-config-management-for-the-private-cluster)
   * [Deploying the Config Management Operator:](#deploying-the-config-management-operator)
   * [Create the git-creds Secret:](#create-the-git-creds-secret)
   * [Configuring the Config Management Operator:](#configuring-the-config-management-operator)
   * [Verifying the installation](#verifying-the-installation)


### Prerequisites

#### Install Nomos command

Download Nomos command binary from
https://cloud.google.com/anthos-config-management/docs/nomos-command

For mac OS get darwin_amd64 and for Cloud Shell get linux_amd64
After downloading the binary, configure it to be executable by using the chmod command:

For mac OS:
```console
  chmod +x v0.13.1_darwin_amd64_nomos
```

For Cloud Shell:
```console
	chmod +x v0.13.1_linux_amd64_nomos
```


Copy the executable binary to /usr/local/bin:

For mac OS:
```console
  sudo cp v0.13.1_darwin_amd64_nomos /usr/local/bin/nomos
```

For Cloud Shell:
```console
	sudo cp v0.13.1_linux_amd64_nomos /usr/local/bin/nomos
```


Verify Nomos has been installed successfully, by giving the command:
```console
  $which nomos

Output should look like this:
/usr/local/bin/nomos
```

#### Install kustomize:

Install Kustomize

On macOS, you can install kustomize with Homebrew package manager:

```console
  brew install kustomize
```
On cloud shell:
```console
	opsys=linux  # or darwin, or windows

  # Get the latest version of kustomize
  curl -s https://api.github.com/repos/kubernetes-sigs/kustomize/releases/latest |\
  grep browser_download |\
  grep $opsys |\
  cut -d '"' -f 4 |\
  xargs curl -O -L

  Copy Kustomize to /usr/local/bin location only for cloud shell:
  ```console
    sudo cp kustomize /usr/local/bin/kustomize
  ```

  Make the kustomize binary executable:
  ```console
  sudo chmod +x /usr/local/bin/kustomize
  ```

Verify kustomize is working correctly:
```console
  which kustomize
```
The output on your console should look like this:
```console
  /usr/local/bin/kustomize
```

#### Install kubectl on macOS

Download the latest release:
```console
	curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/darwin/amd64/kubectl
```

Make the kubectl binary executable:
```console
	chmod +x ./kubectl
```

Move the binary in to your PATH.
```console
	sudo mv ./kubectl /usr/local/bin/kubectl
```

Test to ensure the version you installed is up-to-date:
```console
	kubectl version
```

### Setting up access to the private cluster:

If not done already, you may want to alias kubectl for accessing the private cluster, using the steps below.
This may save you typing the full command, everytime you want to access the private cluster using https proxy.

```console
alias k="HTTPS_PROXY=localhost:8888 kubectl"
k get pods --all-namespaces
```

NAMESPACE     NAME                                                        READY   STATUS    RESTARTS   AGE
kube-system   calico-node-f49fd                                           2/2     Running   0          25m
kube-system   calico-node-sj8pp                                           2/2     Running   0          25m
kube-system   calico-node-tw84c                                           2/2     Running   0          26mZ

...snip...

kube-system   prometheus-to-sd-4xb67                                      1/1     Running   0          27m
kube-system   prometheus-to-sd-fnd2l                                      1/1     Running   0          27m
kube-system   stackdriver-metadata-agent-cluster-level-594ff5c995-htszq   1/1     Running   3          28m


### Initializing your repo:

Once you have set up access to your private cluster, you need to clone a repo and initialize it using nomos command:
Please follow the below steps:

Change the directory to 'anthos':
```console
cd ../anthos
```

Setup the values for your repo ID, Project and account name:
```console
REPO="anthos-demo"
PROJECT=$(gcloud config list --format 'value(core.project)' 2>/dev/null)
ACCOUNT=$(gcloud config list --format 'value(core.account)' 2>/dev/null)
```

Create a cloud source repo:
```console
gcloud source repos create "${REPO}"
```

Clone the repo and cd into the cloned repo:
```console
gcloud source repos clone "${REPO}"
cd "${REPO}"
```

Initialize the repo using nomos:
```console
nomos init
```

```console
Add files to the cloned repo, commit and push the change:

git add .
git commit -m 'Adding initial files for nomos'
git push
```

This creates the basic directory structure of your repo, including the system/, cluster/, and namespaces/ directories.

### Creating configs:

Anthos Config Management keeps your enrolled clusters in sync using configs. A config is a YAML or JSON file that is stored in your repo and contains the same types of configuration details that you can manually apply to a cluster using the kubectl apply command. This [topic](https://cloud.google.com/anthos-config-management/docs/how-to/configs#examples) covers how configs work, how to write them, and how Anthos Config Management applies them to your enrolled clusters.

#### Creating a config

When you create a config, you need to decide the best location in the repo and the fields to include.

#### Location in the repo

The location of a config in the repo is one factor that determines which clusters it applies to.

1. Configs for cluster-scoped objects except for Namespaces are stored in the clusters/ directory of the repo.
2. Configs for Namespaces and Namespace-scoped objects are stored in the namespaces/ directory of the repo.
3. Configs for Anthos Config Management components are stored in the system/ directory of the repo.
4. Config for the Config Management Operator is not stored directly in the repo and is not synced.

#### Example config:

As an example, the below config creates a Namespace called audit.

```console
# Copy the files from example folder into your current folder
cp -R ../anthos-config-example/namespaces/audit namespaces/
```

```console
cat <<EOT >> .gitignore
anthos-demo-key
anthos-demo-key.pub
EOT
```

```console
Add files to the cloned repo, commit and push the change:

git add .
git commit -m 'Adding namespace'
git push
```

### Installing Anthos Config Management for the private cluster

#### Deploying the Config Management Operator:

To enroll a cluster in Anthos Config Management, you deploy the Operator, then create the git-creds Secret, and finally configure the Operator.

You should install the nomos command (as given in the above steps) before continuing so that you can use the nomos status subcommand to detect any issues during installation and setup.

After ensuring that you meet all the prerequisites, you can deploy the Operator by downloading and applying a YAML manifest.

Step 1. Download the latest version of the Operator CRD using the following command. To download a specific version instead, see Downloads.

```console
gsutil cp gs://config-management-release/released/latest/config-management-operator.yaml config-management-operator.yaml
```

Step 2. Apply the CRD:

```console
k apply -f config-management-operator.yaml
```

#### Create the git-creds Secret:

The Operator needs read-only access to your Git repository (the repo) so it can read the configs committed to the repo and apply them to your clusters. If credentials are required, they are stored in the git-creds Secret on each enrolled cluster.

Below are the steps to create credentials using an SSH keypair:

1. Ceate an SSH keypair to allow the Operator to authenticate to your Git repository. This is necessary if you need to authenticate to the repository in order to clone it or read from it.

The following command creates 4096-bit RSA key. Replace [GIT REPOSITORY USERNAME] and /path/to/[KEYPAIR-FILENAME] with the values you want the Operator to use to authenticate to the repository.

```console
ssh-keygen -t rsa -b 4096 \
 -C "${ACCOUNT}" \
 -N '' \
 -f ./anthos-demo-key
```

2. Please add the following ssh public key to the Cloud Source Repo:

You can find the name of the key-file by using a cat command:

```console
cat anthos-demo-key.pub
```

Add the SSH Key Here:  https://source.cloud.google.com/user/ssh_keys"

3. Add the private key to a new Secret in the cluster.

```console
k create secret generic git-creds \
 --namespace=config-management-system \
 --from-file=ssh=./anthos-demo-key
```

4. Delete the private key from the local disk or otherwise protect it.

#### Configuring the Config Management Operator:

To configure the behavior of the Operator, you create a configuration file for the ConfigManagement [CustomResource](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/), then apply it using the kubectl apply command.

Step 1: The spec field contains configuration details such as the location of the repo among other things. Do not change configuration values outside the spec field.

Use the below example as a starting point for your Operator configuration. Save it to a file called config-management.yaml. Be sure to set spec.git.secretType to ssh.

```console
# config-management.yaml

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
```

Step 2: Applying the configuration to the cluster

To apply the configuration, use the kubectl apply command.

```console
k apply -f config-management.yaml
```

#### Verifying the installation

You can use the nomos status command to check if the Operator is installed successfully. Please note that the nomos status needs to communicate to the private cluster over the proxy.

```console
alias n="HTTPS_PROXY=localhost:8888 nomos"
n status
```

Once verified, the alias on nomos command for private cluster access, could be removed using:

```console
unalias n
```

A valid installation with no problems has a status of PENDING or SYNCED. An invalid or incomplete installation has a status of NOT INSTALLED OR NOT CONFIGURED. The output also includes any reported errors.

When the Operator is deployed successfully, it runs in a Pod whose name begins with config-management-operator, in the kube-system Namespace. The Pod may take a few moments to initialize. Verify that the Pod is running:

```console
k -n kube-system get pods | grep config-management
```

If the Pod is running, the command's response is similar (but not identical) to the following:

```console
config-management-operator-6f988f5fdd-4r7tr 1/1 Running 0 26s
```

You can also verify that the config-management-system Namespace exists:

```console
k get ns | grep 'config-management-system'
```

The command's output is similar to the following

config-management-system Active 1m

Once verified, the alias on kubectl for private cluster access could be removed using:

```console
unalias k
```

It is possible to have an invalid configuration that isn't detected right away, such as a missing or invalid git-creds Secret. For troubleshooting steps, see (Valid but incorrect ConfigManagement object in the Troubleshooting)[https://cloud.google.com/anthos-config-management/docs/how-to/installing#configmanagement-status-fields] document.
