#!/bin/bash

exec &> /var/log/init-aws-kubernetes-node.log

set -o verbose
set -o errexit
set -o pipefail

export KUBEADM_TOKEN=${kubeadm_token}
export MASTER_IP=${master_private_ip}
export DNS_NAME=${dns_name}
export KUBERNETES_VERSION="1.23.2"

# Set this only after setting the defaults
set -o nounset

# We to match the hostname expected by kubeadm an the hostname used by kubelet
LOCAL_IP_ADDRESS=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
FULL_HOSTNAME="$(curl -s http://169.254.169.254/latest/meta-data/hostname)"

# Make DNS lowercase
DNS_NAME=$(echo "$DNS_NAME" | tr 'A-Z' 'a-z')

########################################
########################################
# Disable SELinux
########################################
########################################

# setenforce returns non zero if already SE Linux is already disabled
is_enforced=$(getenforce)
if [[ $is_enforced != "Disabled" ]]; then
  setenforce 0
  sed -i 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/selinux/config
fi

########################################
########################################
# Install containerd
########################################
########################################
cat <<EOF | tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

# Setup required sysctl params, these persist across reboots.
cat <<EOF | tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

# Apply sysctl params without reboot
sysctl --system

yum install -y yum-utils curl gettext device-mapper-persistent-data lvm2
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo yum install -y containerd.io
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
sed -i '/^          \[plugins\."io\.containerd\.grpc\.v1\.cri"\.containerd\.runtimes\.runc\.options\]/a \            SystemdCgroup = true' /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd

########################################
########################################
# Install docker
########################################
########################################

# yum install -y yum-utils curl gettext device-mapper-persistent-data lvm2 docker

# # Start services
# systemctl enable docker
# systemctl start docker

# # Set settings needed by Docker
# sysctl net.bridge.bridge-nf-call-iptables=1
# sysctl net.bridge.bridge-nf-call-ip6tables=1


########################################
########################################
# Install Kubernetes components
########################################
########################################
sudo cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
exclude=kubelet kubeadm kubectl
EOF

yum install -y kubelet-$KUBERNETES_VERSION kubeadm-$KUBERNETES_VERSION kubernetes-cni --disableexcludes=kubernetes

# Start services
systemctl enable kubelet
systemctl start kubelet

# Fix certificates file on CentOS
if cat /etc/*release | grep ^NAME= | grep CentOS ; then
    rm -rf /etc/ssl/certs/ca-certificates.crt/
    cp /etc/ssl/certs/ca-bundle.crt /etc/ssl/certs/ca-certificates.crt
fi

########################################
########################################
# Initialize the Kube node
########################################
########################################
cat >/tmp/kubeadm.yaml <<EOF
---
apiVersion: kubeadm.k8s.io/v1beta2
kind: JoinConfiguration
discovery:
  bootstrapToken:
    apiServerEndpoint: $MASTER_IP:6443
    token: $KUBEADM_TOKEN
    unsafeSkipCAVerification: true
  timeout: 5m0s
  tlsBootstrapToken: $KUBEADM_TOKEN
nodeRegistration:
  kubeletExtraArgs:
    cloud-provider: aws
    read-only-port: "10255"
    cgroup-driver: systemd
  name: $FULL_HOSTNAME
---
EOF

kubeadm reset --force
kubeadm join --config /tmp/kubeadm.yaml
