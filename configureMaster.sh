#!/bin/bash
set -e
kubeadm config images pull

cat <<EOF | sudo tee kubeadm-config-iptables-mode.yaml
apiVersion: kubeadm.k8s.io/v1beta2
kind: ClusterConfiguration
networking:
  serviceSubnet: 10.11.0.0/16
  podSubnet: 10.10.0.0/16
  dnsDomain: cluster.local
---
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: iptables
EOF

kubeadm config migrate --old-config kubeadm-config-iptables-mode.yaml --new-config kubeadm-config-iptables-mode-new.yaml

kubeadm init --config kubeadm-config-iptables-mode-new.yaml

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

curl -O -L  https://github.com/projectcalico/calicoctl/releases/download/v3.21.5/calicoctl-linux-amd64
chmod +x calicoctl-linux-amd64
sudo mv calicoctl-linux-amd64 /usr/local/bin/calicoctl

sudo mkdir -p /etc/calico/
cat <<EOF | sudo tee /etc/calico/calicoctl.cfg
apiVersion: projectcalico.org/v3
kind: CalicoAPIConfig
metadata:
spec:
  datastoreType: "kubernetes"
  kubeconfig: "/etc/kubernetes/admin.conf"
EOF


kubectl create -f https://docs.projectcalico.org/manifests/tigera-operator.yaml

curl -O -L https://docs.projectcalico.org/manifests/custom-resources.yaml

sed -i 's/192.168.0.0\/16/cidr: 10.10.0.0\/24/g' custom-resources.yaml

sed -i 's/encapsulation: VXLANCrossSubnet/encapsulation: None/g' custom-resources.yaml

kubectl create -f custom-resources.yaml

