#!/bin/bash

set -e
set -x

# master 节点
sudo apt install nfs-kernel-server
sudo apt install nfs-common

BASE_DIR=${BASE_DIR:-"/mnt/disk1/autocv"}
DATA_DIR=${DATA_DIR:-"$BASE_DIR/data"}
VALUES_LOC=${VALUES_LOC:-"${BASE_DIR}/packages/arm64-jetson/values.yaml"}
CHART_LOC=${CHART_LOC:-"${BASE_DIR}/packages/arm64-jetson/autocv-22.12.2-rc0.tgz"}
ls "$DATA_DIR"
ls "$VALUES_LOC"
ls "$CHART_LOC"

setup_nfs_server() {
  echo '# /etc/exports: the access control list for filesystems which may be exported
#               to NFS clients.  See exports(5).
#
# Example for NFSv2 and NFSv3:
# /srv/homes       hostname1(rw,sync,no_subtree_check) hostname2(ro,sync,no_subtree_check)
#
# Example for NFSv4:
# /srv/nfs4        gss/krb5i(rw,sync,fsid=0,crossmnt,no_subtree_check)
# /srv/nfs4/homes  gss/krb5i(rw,sync,no_subtree_check)
#
/mnt/disk1/autocv/data *(rw,sync,no_subtree_check,no_root_squash)
' | sudo tee /etc/exports

  # 暴露 NFS 共享目录
  sudo exportfs -a
  # 重新启动 NFS Server
  sudo systemctl restart nfs-kernel-server
}

setup_values() {
  local local_ip
  local_ip=$(kubectl get node -owide|grep master|awk '{print $6}'|grep -v INTERNAL)

  sed -i 's|type: local|type: nfs|g' "$VALUES_LOC"
  sed -i "s|local:\n      |nfs:\n      server: ${local_ip}\n|g" "$VALUES_LOC"
}

uninstall() {
  helm uninstall autocv

  kubectl get deploy | grep "scene-ins" | awk '{print $1}' | xargs kubectl delete deploy

  while true; do
    if ! kubectl get pv default-autocv-pv; then
      echo "Persistent volume 'default-autocv-pv' released. Exiting."
      break
    else
      echo "Waiting for persistent volume 'default-autocv-pv' to be deleted."
      sleep 3 # 等待5秒后再次检查
    fi
  done
  return 0
}

install() {
  helm install -f "${VALUES_LOC}" autocv "$CHART_LOC"
  watch "kubectl get po"
}

show_worker_info() {
  echo "You can add a worker to current cluster by using following commands:"
  echo "===================================================================="
  echo "
register_worker() {
  sudo apt install curl -y
  export MASTER_TOKEN=$(sudo cat /var/lib/rancher/k3s/server/node-token)
  export MASTER_IP=$(kubectl get node -owide|grep master|awk '{print $6}'|grep -v INTERNAL)
  k3s-killall.sh
  k3s-uninstall.sh
  curl -sfL https://get.k3s.io |INSTALL_K3S_VERSION=v1.19.16+k3s1 K3S_URL=https://\${MASTER_IP}:6443 K3S_TOKEN=\${MASTER_TOKEN} sh -s - --docker
}

register_worker
  "
  echo "===================================================================="
}

{
  setup_nfs_server
  uninstall
  setup_values
  install
  show_worker_info
}