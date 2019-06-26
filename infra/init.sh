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
echo "Welcome to Kubernetes Under The Hood!   Within 10-12 minutes of first login, you'll have cluster access.  Type 'kubectl cluster-info' to confirm connectivity"
EOF
. ~/.bashrc
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

nohup ~/materials/infra/deploy.sh  &

