#!/bin/bash

set -xu

git submodule foreach --recursive git submodule sync && git submodule update --init --recursive

cd kubo-deployment/manifests

echo "export BOSH_DEPLOYMENT=$JUPYTERHUB_CLIENT_ID" > ~/.bashrc
chmod +x ~/.bashrc
echo "export CLUSTER_HOSTNAME=$(echo $JUPYTERHUB_CLIENT_ID | cut -d'-' -f3-)" >> ~/.bashrc
echo "export CLUSTER_API=$(echo $JUPYTERHUB_CLIENT_ID | cut -d'-' -f3-).k8s.ycf.link" >> ~/.bashrc
echo "cat ~/materials/infra/logo.txt" >> ~/.bashrc
cat <<EOF >>~/.bashrc
echo "Welcome to Kubernetes Under The Hood!   Within 10-12 minutes of first login, you'll have cluster access. " 
echo "Run 'kubectl cluster-info' to verify"
EOF
. ~/.bashrc
cat <<EOF >$BOSH_DEPLOYMENT-cc.yml
vm_extensions:  
  - cloud_properties:  
      target_pool: jupyterhub-$CLUSTER_HOSTNAME-mpool
      ephemeral_external_ip: true  
      service_account: pks-485@fe-scharlton.iam.gserviceaccount.com
    name: $BOSH_DEPLOYMENT-master-cloud-properties  
  - cloud_properties:  
      service_account: pks2-298@fe-scharlton.iam.gserviceaccount.com
      ephemeral_external_ip: true  
    name: $BOSH_DEPLOYMENT-worker-cloud-properties  
EOF

bosh -n update-config --name=$BOSH_DEPLOYMENT-cc --type=cloud ./$BOSH_DEPLOYMENT-cc.yml

        while true; do
           credhub login --server 10.0.0.11:8844 --client-name=$BOSH_CLIENT --client-secret=$BOSH_CLIENT_SECRET --skip-tls-validation
           retVal=$?
           if [ $retVal -eq 0 ]; then
              break
           fi
        done
        ~/materials/infra/kubo-deployment/bin/set_kubeconfig p-bosh/$BOSH_DEPLOYMENT https://$CLUSTER_API:8443
        MASTER_VM=$(bosh vms | grep master | cut -f5)
        echo $GOOGLE > gc.json
        gcloud auth activate-service-account --key-file=gc.json
        gcloud config set project fe-scharlton
        gcloud compute addresses create jupyterhub-$CLUSTER_HOSTNAME-mip --region us-east1
        gcloud compute target-pools create jupyterhub-$CLUSTER_HOSTNAME-mpool --region us-east1

        gcloud compute forwarding-rules create jupyterhub-$CLUSTER_HOSTNAME-mrule --region us-east1 --ports 8443 --address jupyterhub-$CLUSTER_HOSTNAME-mip --target-pool jupyterhub-$CLUSTER_HOSTNAME-mpool

nohup bosh -n deploy ./cfcr.yml \
 -o ops-files/misc/scale-to-one-az.yml \
 -o ops-files/add-hostname-to-master-certificate.yml \
 -o ops-files/change-cidrs.yml \
-o ops-files/master-kubelet.yml \
-o ops-files/disable-flannel-enable-ipam.yml \
-o ops-files/allow-privileged-containers.yml \
-o ops-files/use-vm-extensions.yml  \
-o ops-files/cni/calico.yml  \
-o ops-files/misc/deployment-name.yml \
-o ops-files/vm-types.yml \
-o ops-files/iaas/gcp/cloud-provider.yml \
-v api-hostname=$CLUSTER_API \
 -v master_vm_type=small \
 -v worker_vm_type=large \
 -v apply_addons_vm_type=micro \
 -v deployment_name=$BOSH_DEPLOYMENT \
 -v kubedns_service_ip=10.100.200.2 \
 -v service_cluster_cidr=10.100.200.0/24 \
 -v pod_network_cidr=10.200.0.0/16 \
 -v project_id=fe-scharlton \
 -v director_name=p-bosh \
 -v network=bosh-1-net \
 -v first_ip_of_service_cluster_cidr=10.100.200.1 2>&1 >> bosh.log &
nohup ~/materials/infra/lb.sh 2>&1 >> lb.log &
disown
disown -a

python -m bash_kernel.install
mkdir -p ~/.local/share/jupyter/kernels/gophernotes \
    && cp -r /go/src/github.com/gopherdata/gophernotes/kernel/* ~/.local/share/jupyter/kernels/gophernotes 
