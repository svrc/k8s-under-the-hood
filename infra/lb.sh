#!/bin/bash

set -xu

if [[ ! $(dig $CLUSTER_API A +short) ]]; then
        MASTER_VM=$(bosh vms | grep master | cut -f5)
        bosh -n run-errand apply-specs  &
        echo $GOOGLE > gc.json
        gcloud auth activate-service-account --key-file=gc.json
        gcloud compute addresses create jupyterhub-$CLUSTER_HOSTNAME-mip --region us-west1
        gcloud compute target-pools create jupyterhub-$CLUSTER_HOSTNAME-mpool --region us-west1
        gcloud compute target-pools add-instances jupyterhub-$CLUSTER_HOSTNAME-mpool --instances $MASTER_VM --region us-west1
        gcloud compute forwarding-rules create jupyterhub-$CLUSTER_HOSTNAME-mrule --region us-west1 --ports 8443 --address jupyterhub-$CLUSTER_HOSTNAME-mip --target-pool jupypter-$CLUSTER_HOSTNAME-mpool
        PUBLIC_MASTER_IP=$(gcloud compute forwarding-rules describe jupyterhub-$CLUSTER_HOSTNAME-mrule --region us-west1 | grep IPAddress | cut -d" " -f2)
        gcloud dns record-sets transaction start -z k8sycf
        gcloud dns record-sets transaction add -z k8sycf --name "$CLUSTER_API" --ttl "300" --type="A" "$PUBLIC_MASTER_IP"
        gcloud dns record-sets transaction execute -z k8sycf
fi
