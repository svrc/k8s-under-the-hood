#!/bin/bash

set -xu

sleep 10

while [[ $(bosh tasks | grep $BOSH_DEPLOYMENT) ]]; do
  sleep 10
done

        credhub login --server 10.0.0.11:8844 --client-name=$BOSH_CLIENT --client-secret=$BOSH_CLIENT_SECRET --skip-tls-validation
        ~/materials/infra/kubo-deployment/bin/set_kubeconfig p-bosh/$BOSH_DEPLOYMENT https://$CLUSTER_API:8443
        MASTER_VM=$(bosh vms | grep master | cut -f5)
        bosh -n run-errand apply-specs 2>&1 >> specs.log  &
        echo $GOOGLE > gc.json
        gcloud auth activate-service-account --key-file=gc.json
        gcloud config set project fe-scharlton
        gcloud compute addresses create jupyterhub-$CLUSTER_HOSTNAME-mip --region us-east1
        gcloud compute target-pools create jupyterhub-$CLUSTER_HOSTNAME-mpool --region us-east1
        gcloud compute target-pools add-instances jupyterhub-$CLUSTER_HOSTNAME-mpool --instances $MASTER_VM --instances-zone us-east1-b
        gcloud compute forwarding-rules create jupyterhub-$CLUSTER_HOSTNAME-mrule --region us-east1 --ports 8443 --address jupyterhub-$CLUSTER_HOSTNAME-mip --target-pool jupyterhub-$CLUSTER_HOSTNAME-mpool
        PUBLIC_MASTER_IP=$(gcloud compute forwarding-rules describe jupyterhub-$CLUSTER_HOSTNAME-mrule --region us-east1 | grep IPAddress | cut -d" " -f2)
        for i in {0..5}; do
         gcloud dns record-sets transaction start -z k8sycf
         gcloud dns record-sets transaction add -z k8sycf --name "$CLUSTER_API" --ttl "60" --type="A" "$PUBLIC_MASTER_IP"
         gcloud dns record-sets transaction execute -z k8sycf
         if [  $? -eq 0 ]; then
          break
         fi
         sleep 1
       done
