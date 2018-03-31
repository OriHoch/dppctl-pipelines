#!/usr/bin/env bash

sudo apt-get update && sudo apt-get install -y util-linux &&\
curl -Lo kubectl https://storage.googleapis.com/kubernetes-release/release/v1.9.4/bin/linux/amd64/kubectl && chmod +x kubectl && sudo mv kubectl /usr/local/bin/ &&\
curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64 && chmod +x minikube && sudo mv minikube /usr/local/bin/ &&\
curl -L https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get | sudo bash &&\
sudo minikube start --vm-driver=none --kubernetes-version=v1.9.4 &&\
minikube update-context &&\
JSONPATH='{range .items[*]}{@.metadata.name}:{range @.status.conditions[*]}{@.type}={@.status};{end}{end}'; until kubectl get nodes -o jsonpath="$JSONPATH" 2>&1 | grep -q "Ready=True"; do sleep 1; done &&\
while ! ( helm init --history-max 1 --upgrade --wait &&\
          helm version ); do
    sleep 2
done
