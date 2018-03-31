#!/usr/bin/env bash

curl -Lo kubectl https://storage.googleapis.com/kubernetes-release/release/v1.9.4/bin/linux/amd64/kubectl && chmod +x kubectl && sudo mv kubectl /usr/local/bin/ &&\
curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64 && chmod +x minikube && sudo mv minikube /usr/local/bin/ &&\
curl -Lo helm https://storage.googleapis.com/kubernetes-helm/helm-v2.8.2-linux-amd64.tar.gz && chmod +x helm && sudo mv helm /usr/local/bin/ &&\
sudo minikube start --vm-driver=none --kubernetes-version=v1.9.4 &&\
minikube update-context &&\
JSONPATH='{range .items[*]}{@.metadata.name}:{range @.status.conditions[*]}{@.type}={@.status};{end}{end}'; until kubectl get nodes -o jsonpath="$JSONPATH" 2>&1 | grep -q "Ready=True"; do sleep 1; done
