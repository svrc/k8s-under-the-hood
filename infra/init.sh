#/bin/sh

git submodule foreach --recursive git submodule sync && git submodule update --init --recursive

cd kubo-deployment/manifests

export BOSH_DEPLOYMENT=$JUPYTERHUB_CLIENT_ID
echo "export BOSH_DEPLOYMENT=$JUPYTERHUB_CLIENT_ID" >> ~/.bash_profile
export CLUSTER_HOSTNAME=$(echo $JUPYTERHUB_CLIENT_ID | cut -d'-' -f3-).k8s.ycf.link

cat <<EOF >>$BOSH_DEPLOYMENT-cc.yml
vm_extensions:  
  - cloud_properties:  
      ephemeral_external_ip: true  
    name: $BOSH_DEPLOYMENT-master-cloud-properties  
  - cloud_properties:  
      ephemeral_external_ip: true  
    name: $BOSH_DEPLOYMENT-worker-cloud-properties  
EOF

bosh -n update-config --name=$BOSH_DEPLOYMENT-cc --type=cloud ./$BOSH_DEPLOYMENT-cc.yml

bosh -n deploy ./cfcr.yml \
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
-v api-hostname=$CLUSTER_HOSTNAME \
 -v master_vm_type=small \
 -v worker_vm_type=large \
 -v apply_addons_vm_type=micro \
 -v deployment_name=$BOSH_DEPLOYMENT \
 -v kubedns_service_ip=10.100.200.2 \
 -v service_cluster_cidr=10.100.200.0/24 \
 -v pod_network_cidr=10.200.0.0/16 \
 -v first_ip_of_service_cluster_cidr=10.100.200.1 2>&1 >> ./bosh.log &

MASTER_IP=$(bosh vms | grep master | cut -f4)
echo "$MASTER_IP   $CLUSTER_HOSTNAME" >> /etc/hosts
