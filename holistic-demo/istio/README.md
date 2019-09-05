## Deployment

The gke-tf-demo.yaml cluster you deployed was set with istio enabled by default. Please note that enabling pod-security policy alongside Istio will cause issues with Istio's deployment.


Open the `scripts/istio.env` file and set:

  * `ISTIO_PROJECT` to the ID of the project where you deployed the holistic demo cluster.
  ```
    echo $PROJECT # Bash variable with your cluster's project id
  ```
  * `GCE_PROJECT` to the ID of the project you want to use for GCE
  * Remaining variables that are based on the demo cluster yaml for the holsitic-demo.

Note that the ID of the project is not always the same as the name. Also, please note that when setting `ISTIO_PROJECT` and `GCE_PROJECT` they should be uncommented. Failure to do so will result in an error in the following step.

```
  # From the istio directory:
  source ./scripts/setenvironment.sh
```

## Terraform Deployment

The Terraform in the istio directory is managed with a separate state file from the root holistic-demo.

```
  source ./scripts/terraformcreation.sh
```

## Istio Setup

We will be copying yaml files into the anthos config management repository we set up in the previous part of the holstic demo.

```
  REPO_PATH=<INSERT_PATH_TO_REPO>
```

In order to configure for Istio, we need add a clusterrolebinding in our gke cluster:

```
  mkdir $REPO_PATH/cluster
  cp $ROOT/config-management/cluster/clusterrolebinding.yaml $REPO_PATH/cluster/.
```

Push the file changed and validate that the changes made it:

```
  git add .
  git commit -m "Added role binding."
  git push origin master

  n status
```

We are going to update the default namespace with the "istio-injected" label also through anthos config management:

```
  cp $ROOT/config-management/namespaces/default/namespace.yaml $REPO_PATH/namespaces/default/.
  git add .
  git commit -m "Modified default namespace to have label for istio"
  git push origin master
```

In the Istio folder we downloaded, there is a "mesh-expansion.yaml" located at $ISTIO_DIR/install/kubernetes/mesh-expansion.yaml that we are going to split up and place into our config management. We will need to manage the "istio-system" and "kube-system" namespaces in our repository:

```
  mkdir $REPO_PATH/namespaces/istio-system
  cp $ROOT/config-management/namespaces/istio-system/namespace.yaml $REPO_PATH/namespaces/istio-system/.

  mkdir $REPO_PATH/namespaces/kube-system
  cp $ROOT/config-management/namespaces/kube-system/namespace.yaml $REPO_PATH/namespaces/kube-system/.

  git add .
  git commit -m "Added isio-system and kube-system into the anthos repository."
  git push origin master
```

You will need to split the 'mesh-expansion' file into a file for each namespace in your anthos repository. and commit those changes:

```
  # YOUR TASK: Split mesh-expansion.yaml

  # Commit the changes you made
  git add .
  git commit -m "Split mesh-expansion.yaml."
  git push origin master
```

We will now move to doing the rest of the tutorial in the bastion host for the private cluster:

```
  # Navigate to the terraform directory of the holistic-demo
  $(terraform output bastion_ssh)

  # Install kubectl on the bastion host
  sudo apt-get install kubectl
```

You will need to authenticate as your user temporarily within the bastion to deploy resources without permission issues:

```
  gcloud auth login --no-launch-browser
```

In your bastion cluster, be sure to download the repo and set up the environment again:

```
  sudo apt-get install git
  git clone --recursive https://github.com/GoogleCloudPlatform/gke-anthos-holistic-demo
```

Open the `scripts/istio.env` file and set:
  * `ISTIO_PROJECT`
  * `GCE_PROJECT`
  * Remaining variables that are based on the demo cluster yaml for the holistic-demo.

We will now configure the environment for the bastion VM:

```
  # From the istio directory:
  source ./scripts/setenvironment.sh
  gcloud container clusters get-credentials --project ${ISTIO_PROJECT} --region ${REGION} --internal-ip ${ISTIO_CLUSTER}

```

The bookinfo application we are deploying requires [Mesh Expansion](https://istio.io/docs/setup/kubernetes/additional-setup/mesh-expansion/) to be configured.

```
  source ./scripts/meshsetup.sh
  (
    # Register the external service with the Istio mesh
    chmod +x "$ISTIO_DIR/bin/istioctl"
    "$ISTIO_DIR/bin/istioctl" register -n vm mysqldb "$(gcloud compute instances describe "${GCE_VM}" \
      --format='value(networkInterfaces[].networkIP)' --project "${GCE_PROJECT}" --zone "${ZONE}")" 3306
  )
```

All that remains is to deploy the bookinfo application:

```

  # Install the bookinfo services and deployments and set up the initial Istio
  # routing. For more information on routing see this Istio blog post:
  # https://istio.io/blog/2018/v1alpha3-routing/
  kubectl apply -n default \
    -f "$ISTIO_DIR/samples/bookinfo/platform/kube/bookinfo.yaml"
  kubectl apply -n default \
    -f "$ISTIO_DIR/samples/bookinfo/networking/bookinfo-gateway.yaml"
  kubectl apply -n default \
    -f "$ISTIO_DIR/samples/bookinfo/networking/destination-rule-all-mtls.yaml"

  # Change the routing to point to the most recent versions of the bookinfo
  # microservices
  kubectl apply -n default \
    -f "$ISTIO_DIR/samples/bookinfo/networking/virtual-service-reviews-v3.yaml"
  kubectl apply -n default \
    -f "$ISTIO_DIR/samples/bookinfo/networking/virtual-service-ratings-mysql-vm.yaml"
  kubectl apply -n default \
    -f "$ISTIO_DIR/samples/bookinfo/platform/kube/bookinfo-ratings-v2-mysql-vm.yaml"

  # Install and deploy the database used by the Istio service
  gcloud compute ssh "${GCE_VM}" --project="${GCE_PROJECT}" --zone "${ZONE}" \
    --command "$(cat "$ROOT"/scripts/setup-gce-vm.sh)"

```

We can now get the website information to view the webpage:

```
  source ./scripts/getwebsiteinfo.sh
```

When you are done deploying from the bastion, revoke your authenticated user:

```
  gcloud auth revoke
```

## Testing
```
  make validate
```
Validate will insert random ratings into the webpage and check the webpage for a change in the UI.

## Teardown
In order to spin down the resources we created without affecting the cluster, we are going to remove some of the resources we created in the cluster (both through kubectl and our Anthos repo), and then we will destroy the resources we deployed in this folder via teraform.

In the bastion host:
```
kubectl delete -n default \
  -f "$ISTIO_DIR/samples/bookinfo/platform/kube/bookinfo.yaml"
kubectl delete -n default \
  -f "$ISTIO_DIR/samples/bookinfo/networking/bookinfo-gateway.yaml"
kubectl delete -n default \
  -f "$ISTIO_DIR/samples/bookinfo/networking/destination-rule-all-mtls.yaml"
kubectl delete -n default \
  -f "$ISTIO_DIR/samples/bookinfo/networking/virtual-service-reviews-v3.yaml"
kubectl delete -n default \
  -f "$ISTIO_DIR/samples/bookinfo/networking/virtual-service-ratings-mysql-vm.yaml"
kubectl delete -n default \
  -f "$ISTIO_DIR/samples/bookinfo/platform/kube/bookinfo-ratings-v2-mysql-vm.yaml"
```

After we spin down demo-specific resources, we can thing remove from our git repository any yaml files we pushed into the repo.
```
  git rm cluster/clusterrolebinding.yaml
  git rm namespaces/vm/namespace.yaml

  <Remove additional files based on how you split up mesh-expansion.yaml>

  git add .
  git commit -m "Removing bookinfo application files from anthos config management."
  git push origin master
  n status
```

Now that all resources in the cluster have been removed, we can spin down any resources Terraform created, such as the VM and networking resources.

```
  (cd "$ROOT/terraform"; terraform destroy -var "istio_project=${ISTIO_PROJECT}" \
    -var "gce_project=${GCE_PROJECT}" \
    -var "zone=${ZONE}" \
    -var "region=${REGION}" \
    -var "gce_network=${GCE_NETWORK}" \
    -var "gce_subnet=${GCE_SUBNET}" \
    -var "gce_subnet_cidr=${GCE_SUBNET_CIDR}" \
    -var "istio_network=${ISTIO_NETWORK}" \
    -var "istio_subnet_cidr=${ISTIO_SUBNET_CIDR}" \
    -var "istio_subnet_cluster_cidr=${ISTIO_SUBNET_CLUSTER_CIDR}" \
    -var "istio_subnet_services_cidr=${ISTIO_SUBNET_SERVICES_CIDR}" \
    -var "gce_vm=${GCE_VM}" \
    -input=false -auto-approve)
```

## References
https://istio.io/docs/setup/kubernetes/additional-setup/mesh-expansion/#troubleshooting

