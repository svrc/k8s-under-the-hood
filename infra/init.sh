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
nohup ~/materials/infra/lb.sh &
cat <<EOF >$BOSH_DEPLOYMENT-cc.yml
vm_extensions:  
  - cloud_properties:  
      ephemeral_external_ip: true  
    name: $BOSH_DEPLOYMENT-master-cloud-properties  
  - cloud_properties:  
      ephemeral_external_ip: true  
    name: $BOSH_DEPLOYMENT-worker-cloud-properties  
EOF

bosh -n update-config --name=$BOSH_DEPLOYMENT-cc --type=cloud ./$BOSH_DEPLOYMENT-cc.yml

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
-v api-hostname=$CLUSTER_API \
 -v master_vm_type=small \
 -v worker_vm_type=large \
 -v apply_addons_vm_type=micro \
 -v deployment_name=$BOSH_DEPLOYMENT \
 -v kubedns_service_ip=10.100.200.2 \
 -v service_cluster_cidr=10.100.200.0/24 \
 -v pod_network_cidr=10.200.0.0/16 \
 -v first_ip_of_service_cluster_cidr=10.100.200.1 &
disown
disown -a
credhub login --server 10.0.0.10:8844 --client-name=$BOSH_CLIENT --client-secret=$BOSH_CLIENT_SECRET --skip-tls-validation
