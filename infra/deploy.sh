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
-v api-hostname=$CLUSTER_API \
 -v master_vm_type=small \
 -v worker_vm_type=large \
 -v apply_addons_vm_type=micro \
 -v deployment_name=$BOSH_DEPLOYMENT \
 -v kubedns_service_ip=10.100.200.2 \
 -v service_cluster_cidr=10.100.200.0/24 \
 -v pod_network_cidr=10.200.0.0/16 \
 -v first_ip_of_service_cluster_cidr=10.100.200.1


if [[ ! $(dig $CLUSTER_API A +short) ]]; then
        MASTER_VM=$(bosh vms | grep master | cut -f5)
        bosh -n run-errand apply-specs 

        gcloud compute addresses create jupyterhub-$CLUSTER_HOSTNAME-mip --region us-west1
        gcloud compute target-pools create jupyterhub-$CLUSTER_HOSTNAME-mpool --region us-west1
        gcloud compute target-pools add-instances jupyterhub-$CLUSTER_HOSTNAME-mpool --instances $MASTER_VM --region us-west1
        gcloud compute forwarding-rules create jupyterhub-$CLUSTER_HOSTNAME-mrule --region us-west1 --ports 8443 --address jupyterhub-$CLUSTER_HOSTNAME-mip --target-pool jupypter-$CLUSTER_HOSTNAME-mpool
        PUBLIC_MASTER_IP=$(gcloud compute forwarding-rules describe jupyterhub-$CLUSTER_HOSTNAME-mrule --region us-west1 | grep IPAddress | cut -d" " -f2)
        gcloud dns record-sets transaction start -z k8sycf
        gcloud dns record-sets transaction add -z k8sycf --name "$CLUSTER_API" --ttl "300" --type="A" "$PUBLIC_MASTER_IP"
        gcloud dns record-sets transaction execute -z k8sycf
fi
