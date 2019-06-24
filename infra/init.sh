#/bin/sh

git submodule foreach --recursive git submodule sync && git submodule update --init --recursive

cd kubo-deployment/manifests

export BOSH_DEPLOYMENT=$JUPYTERHUB_CLIENT_ID
export CLUSTER_HOSTNAME=$(echo $JUPYTERHUB_CLIENT_ID | cut -d'-' -f3-).k8s.ycf.link

bosh -n deploy ./cfcr.yml \
 -o ops-files/misc/scale-to-one-az.yml
 -o ops-files/add-hostname-to-master-certificate.yml \
 -o ops-files/change-cidrs.yml \
-o ops-files/master-kubelet.yml \
-o ops-files/disable-flannel-enable-ipam.yaml \
-o ops-files/allow-privileged-containers.yml \
-o ops-files/use-vm-extensions.yml  \
-o ops-files/cni/calico.yml  
-v api-hostname=$CLUSTER_HOSTNAME \
 -v deployment_name=$BOSH_DEPLOYMENT \
 -v kubedns_service_ip=10.100.200.2 \
 -v service_cluster_cidr=10.100.200.0/24 \
 -v pod_network_cidr=10.200.0.0/16 \
 -v first_ip_of_service_cluster_cidr=10.100.200.1 2>&1 >> ./bosh.log &

