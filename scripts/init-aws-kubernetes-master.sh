#!/bin/bash

set -o verbose
set -o errexit
set -o pipefail

if [ -z "$KUBERNETES_VERSION" ]; then
  KUBERNETES_VERSION="1.7.5"
fi

if [ -z "$CLUSTER_NAME" ]; then
  CLUSTER_NAME="aws-kubernetes"
fi

if [ -z "$AWS_SUBNETS" ]; then
  AWS_SUBNETS="$(curl http://169.254.169.254/latest/meta-data/network/interfaces/macs/$(curl http://169.254.169.254/latest/meta-data/mac)/subnet-id)"
fi

# Set this only after setting the defaults
set -o nounset

# Set fully qualified hostname
# This is needed to match the hostname expected by kubeadm an the hostname used by kubelet
hostname $(hostname -f)

# Make DNS lowercase
DNS_NAME=$(echo "${DNS_NAME}" | tr 'A-Z' 'a-z')

# Install AWS CLI client
yum install -y epel-release
yum install -y awscli

# Tag subnets
for SUBNET in $AWS_SUBNETS
do
  aws ec2 create-tags --resources ${SUBNET} --tags Key=kubernetes.io/cluster/${CLUSTER_NAME},Value=shared --region ${AWS_REGION}
done

# Install docker
yum install -y yum-utils device-mapper-persistent-data lvm2
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
yum makecache fast
yum install -y docker-ce

# Install Kubernetes components
sudo cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg
        https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF
setenforce 0
yum install -y kubelet-${KUBERNETES_VERSION} kubeadm-${KUBERNETES_VERSION} kubernetes-cni

# Fix kubelet configuration
sed -i 's/--cgroup-driver=systemd/--cgroup-driver=cgroupfs/g' /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
sed -i '/Environment="KUBELET_CGROUP_ARGS/i Environment="KUBELET_CLOUD_ARGS=--cloud-provider=aws"' /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
sed -i 's/$KUBELET_CGROUP_ARGS/$KUBELET_CLOUD_ARGS $KUBELET_CGROUP_ARGS/g' /etc/systemd/system/kubelet.service.d/10-kubeadm.conf

# Start services
systemctl enable docker
systemctl start docker
systemctl enable kubelet
systemctl start kubelet

# Set settings needed by Docker
sysctl net.bridge.bridge-nf-call-iptables=1
sysctl net.bridge.bridge-nf-call-ip6tables=1

# Fix certificates file on CentOS
if cat /etc/*release | grep ^NAME= | grep CentOS ; then
    rm -rf /etc/ssl/certs/ca-certificates.crt/
    cp /etc/ssl/certs/ca-bundle.crt /etc/ssl/certs/ca-certificates.crt
fi

# Initialize the master
cat >/tmp/kubeadm.yaml <<EOF
---
apiVersion: kubeadm.k8s.io/v1alpha1
kind: MasterConfiguration
token: ${KUBEADM_TOKEN}
cloudProvider: aws
kubernetesVersion: v${KUBERNETES_VERSION}
apiServerCertSANs:
- ${DNS_NAME}
EOF

kubeadm reset
kubeadm init --config /tmp/kubeadm.yaml
rm /tmp/kubeadm.yaml

# Use the local kubectl config for further kubectl operations
export KUBECONFIG=/etc/kubernetes/admin.conf

# Install calico
kubectl apply -f https://s3.amazonaws.com/scholzj-kubernetes/cluster/calico.yaml

# Allow the user to administer the cluster
kubectl create clusterrolebinding admin-cluster-binding --clusterrole=cluster-admin --user=admin

# Prepare the kubectl config file for download to client
export KUBECONFIG_OUTPUT=/home/centos/kubeconfig
kubeadm alpha phase kubeconfig client-certs \
  --client-name admin \
  --server "https://${DNS_NAME}:6443" \
  > $KUBECONFIG_OUTPUT
chown centos:centos $KUBECONFIG_OUTPUT
chmod 0600 $KUBECONFIG_OUTPUT

# Load addons
for ADDON in $ADDONS
do
  curl $ADDON | envsubst > /tmp/addon.yaml
  kubectl apply -f /tmp/addon.yaml
  rm /tmp/addon.yaml
done
