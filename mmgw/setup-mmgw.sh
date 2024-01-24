#!/bin/bash

set -u
set -x
NVMODE=${NVMODE-"false"}

if [ $NVMODE == "true" ]; then
    kubectl apply -f "./mmgw-nv-cm.yaml"
    kubectl apply -f "./mmgw-nv-deploy.yaml"
    kubectl get po -oname |grep mmgw |xargs kubectl delete
else
    kubectl apply -f "./mmgw-cpu-cm.yaml"
    kubectl get po -oname |grep mmgw |xargs kubectl delete
fi
set +x