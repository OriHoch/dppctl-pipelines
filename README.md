# dppctl-pipelines

[![Build Status](https://travis-ci.org/OriHoch/dppctl-pipelines.svg?branch=master)](https://travis-ci.org/OriHoch/dppctl-pipelines)

Part of [dppctl - serverless data pipelines framework](https://github.com/OriHoch/dppctl/blob/master/README.md#dppctl)

Provides the core functionality of running the pipelines and managing related infra

## Prerequisites

The only prerequisite is a Kubernetes cluster with Helm installed.

Following methods are suggested for quick startup, but you can use any method to get a Kubernetes cluster with Helm installed.

### Setting up a local Minikube cluster

* Install Minikube according to the instructions in latest [release notes](https://github.com/kubernetes/minikube/releases)
* Create the local minikube cluster
  * `minikube start`
  * If you have problems, try to downgrade the kubernetes version
    * e.g. `minikube start --kubernetes-version v1.9.0`
* Verify you are connected to the cluster
  * `kubectl get nodes`
* Install [helm client](https://docs.helm.sh/using_helm/#installing-the-helm-client)
* Initialize helm
  * `helm init --history-max 1 --upgrade --wait`
* Verify helm version on both client and server
  * `helm version`
  * should be v1.8.2 or later
* Delete all existing pods to cleanup previous pipelines
  * `kubectl delete pod --all`

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
  * `helm init --service-account tiller --upgrade --history-max 1 --wait`
  * It's important to set history-max because dppctl relies on intalling new releases dynamically
* Delete all existing pods to cleanup previous pipelines
  * `kubectl delete pod --all`


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
while ! kubectl logs pipeline-$ID -c pipeline -f; do sleep 1; done
```

It ends with following the pipeline logs, Press CTRL+C to exit

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
while ! kubectl logs pipeline-$ID -c sync -f; do sleep 1; done
```

Load the workload to google storage

```
( cd examples/noise/workload; zip workload.zip pipeline-spec.yaml noise.py );
gsutil cp -a public-read examples/noise/workload/workload.zip gs://${CLOUDSDK_CORE_PROJECT}-dppctl-pipelines/${ID}/workload.zip
```

Check the logs

```
kubectl logs pipeline-$ID -c sync
kubectl logs pipeline-$ID -c pipeline -f
```

Data is available publically by default

```
echo https://storage.googleapis.com/${CLOUDSDK_CORE_PROJECT}-dppctl-pipelines/${ID}/data/datapackage.json
```

### Workload and data storage locally using minio

Download [minio client](https://github.com/minio/mc/blob/master/README.md#minio-client-quickstart-guide)

```
curl https://dl.minio.io/client/mc/release/linux-amd64/mc > ./mc && chmod +x ./mc
```

Run the pipeline, sync should wait for the workload

```
ID=$(python -c 'import re;import uuid;print(re.sub("-","",str(uuid.uuid4())))') &&\
helm install . -n dppctl-pipelines-$ID --set id=$ID \
               --set workload=minio --set dataSyncer=minio --set enableMinio=1 \
               --set dppRunParams="--verbose ./noise" --set postPipelinesSleepSeconds=3600 \
               --set enableInfo=1 &&\
sleep 1 &&\
while ! kubectl logs pipeline-$ID -c sync -f; do sleep 1; done &&\
sleep 2
```

Upload the workload to minio

```
kubectl port-forward pipeline-$ID 9000 & MINIO_PORT_FORWARD_PID=$!;
./mc config host add dppctl http://localhost:9000 admin 12345678 &&\
while ! ./mc ls dppctl/workload/.__dppctl_ready_for_workload__; do sleep 1; done &&\
./mc cp -q examples/noise/workload/pipeline-spec.yaml dppctl/workload/ &&\
./mc cp -q examples/noise/workload/noise.py dppctl/workload/ &&\
echo "" | ./mc pipe dppctl/workload/.__dppctl_workload_ready__ &&\
kubectl logs pipeline-$ID -c pipeline -f
```

When pipeline is done, data should be available in minio

```
./mc ls dppctl/workload/data
```

Kill the port forward

```
kill $MINIO_PORT_FORWARD_PID
```
