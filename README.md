# dppctl-pipelines

[Kubernetes Helm](https://helm.sh/) chart that installs the dppctl pipelines runner and related infrastructure components.


## Prerequisites

The only prerequisite is a Kubernetes cluster with Helm installed.

Following methods are suggested for quick startup, but you can use any method to get a Kubernetes cluster with Helm installed.

### Setting up a local Minikube cluster

* Install Minikube according to the instructions in latest [release notes](https://github.com/kubernetes/minikube/releases)
* Create the local minikube cluster
  * `minikube start`
* Verify you are connected to the cluster
  * `kubectl get nodes`
* Initialize helm
  * `helm init --history-max 1 --upgrade --wait`
* Verify that it works
  * `helm ls`

### Setting up a cluster on Google Kubernetes Engine

* Using the Google Kubernetes Engine Web UI - Create a Kubernetes Cluster
  * For a development / testing cluster, 2 nodes with 1vCPU each should be enough
  * For a production cluster, use at least 2 nodes with 2vCPU for stability
* Install [gcloud SDK](https://cloud.google.com/sdk/downloads)
* Install kubectl
  * `gcloud components install kubectl`
* Authenticate
  * `gcloud auth login`
* Connect to the cluster
  * For example, if you named the cluster `dppctl` and created it in the default zone us-central1-a:
  * `gcloud container clusters get-credentials dppctl --zone us-central1-a`
* Verify you are connected
  * `kubectl get nodes`
* Install the Helm client
  * `curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get | bash`
* Install the Helm server-side component - Tiller
  * `kubectl create -f tiller-rbac-config.yaml`
  * `helm init --service-account tiller --upgrade --force-upgrade --history-max 1 --wait`
  * It's important to set history-max because dppctl relies on intalling new releases dynamically


## Running pipelines

The `examples` directly contains ready to run pipeline configurations and code

You can test locally first, using Python 3.6, install datapackage-pipelines

`sudo pip3 install --upgrade datapackage-pipelines`

then you can use `dpp` to run pipelines from the examples directory

```
dpp run ./examples/noise/workload/noise
```

Following snippet simulates some of the work `dppctl-operator` is doing

```
ID=$(python -c 'import re;import uuid;print(re.sub("-","",str(uuid.uuid4())))') &&\
helm install . -n dppctl-pipelines-$ID \
               --set id=$ID \
               --set workload=https://github.com/OriHoch/dppctl-pipelines/archive/master.zip \
               --set workloadPath=dppctl-pipelines-master/examples/noise/workload \
               --set dppRunParams="--verbose ./noise" \
               --set postPipelinesSleepSeconds=3600 &&\
sleep 1 &&\
POD=$(kubectl get pods -l dppctl-pipeline=$ID -o go-template='{{(index .items 0).metadata.name}}') &&\
while ! kubectl logs $POD -c pipeline -f; do sleep 1; done
```

It ends with following the pipeline logs, Press CTRL+C to exit

To cleanup, delete all helm releases with `helm ls --short | xargs -L1 helm delete --purge`

### Delayed workload loading + sync to google storage

Pipeline waits for workload, so you can start the job and then upload the workload to start it

This script uses google storage, you should install the [gcloud SDK](https://cloud.google.com/sdk/downloads)

Set your google project ID

```
CLOUDSDK_CORE_PROJECT=google-compute-platform-project-id
```

Create the bucket

```
gsutil mb -p $CLOUDSDK_CORE_PROJECT gs://${CLOUDSDK_CORE_PROJECT}-dppctl-pipelines
```

Create a service account - this can be done from google compute platform web UI - https://console.cloud.google.com/iam-admin/serviceaccounts/project?project=

Save the key and give `Storage Admin` role to the service account

Add the service account json file to the kubernetes cluster as a secret (assuming the service account json is at ./secret-dppctl-data-syncer.json)

```
kubectl create secret generic data-syncer --from-file=secret.json=./secret-dppctl-data-syncer.json
```

Run the pipeline and track the sync container logs - it will wait for workload

```
ID=$(python -c 'import re;import uuid;print(re.sub("-","",str(uuid.uuid4())))') &&\
helm install . -n dppctl-pipelines-$ID --set id=$ID \
               --set workload=https://storage.googleapis.com/${CLOUDSDK_CORE_PROJECT}-dppctl-pipelines/${ID}/workload.zip \
               --set dppRunParams="--verbose ./noise" --set postPipelinesSleepSeconds=3600 \
               --set enableInfo=1 --set dataSyncerSecret=data-syncer --set cloudSdkCoreProject=$CLOUDSDK_CORE_PROJECT &&\
sleep 1 &&\
POD=$(kubectl get pods -l dppctl-pipeline=$ID -o go-template='{{(index .items 0).metadata.name}}') &&\
while ! kubectl logs $POD -c sync -f; do sleep 1; done
```

Load the workload to google storage

```
( cd examples/noise/workload; zip workload.zip pipeline-spec.yaml noise.py );
gsutil cp -a public-read examples/noise/workload/workload.zip gs://${CLOUDSDK_CORE_PROJECT}-dppctl-pipelines/${ID}/workload.zip
```

Check the logs

```
kubectl logs $POD -c sync
kubectl logs $POD -c pipeline -f
```

Data is available publically by default

```
echo https://storage.googleapis.com/${CLOUDSDK_CORE_PROJECT}-dppctl-pipelines/${ID}/data/datapackage.json
```
