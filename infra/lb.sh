#!/bin/bash

set -xu

rm /home/jovyan/materials/infra/kubo-deployment/manifests/transaction.yaml
PUBLIC_MASTER_IP=$(gcloud compute forwarding-rules describe jupyterhub-$CLUSTER_HOSTNAME-mrule --region us-east1 | grep IPAddress | cut -d" " -f2)
OLD_IP=$(gcloud dns record-sets list -z k8sycf  | grep $CLUSTER_API | awk '{print $4}')
if [ -z $OLD_IP ]; then
    for i in {0..5}; do
     gcloud dns record-sets transaction start -z k8sycf
     gcloud dns record-sets transaction add -z k8sycf --name "$CLUSTER_API" --ttl "60" --type="A" "$PUBLIC_MASTER_IP"
     gcloud dns record-sets transaction execute -z k8sycf
     if [  $? -eq 0 ]; then
      break
     fi
     sleep 1
   done
elif [ ! $PUBLIC_MASTER_IP == $OLD_IP ]; then
   for i in {0..5}; do
     gcloud dns record-sets transaction start -z k8sycf
     gcloud dns record-sets transaction remove -z k8sycf --name "$CLUSTER_API" --ttl "60" --type="A" "$OLD_IP"
     gcloud dns record-sets transaction add -z k8sycf --name "$CLUSTER_API" --ttl "60" --type="A" "$PUBLIC_MASTER_IP"
     gcloud dns record-sets transaction execute -z k8sycf
     if [  $? -eq 0 ]; then
      break
     fi
     sleep 1
   done
fi
sleep 10

while [[ $(bosh tasks | grep $BOSH_DEPLOYMENT) ]]; do
  sleep 10
done

bosh -n run-errand apply-specs
