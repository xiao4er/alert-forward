#!/bin/bash

set -u

cfgLoc="./frpc.toml"
cfgTgt="/etc/frpc.toml"
cmdLoc="./frpc-arm64"
cmdTgt="/usr/local/bin/frpc-arm64"
svcName="frpc"
frpcSvcFile="/etc/systemd/system/frpc.service"
daemonSvcName="transwarpd"
daemonSvcFile="/etc/systemd/system/transwarpd.service"
svc="
[Unit]
Description=Sophon Edge Alert Forwarding Service
After=network.target

[Service]
ExecStart=${cmdTgt} -c ${cfgTgt}
Restart=always
User=nobody
RestartSec=3
LimitNOFILE=4096

[Install]
WantedBy=multi-user.target
"

transwarpDaemonSvc="
[Unit]
Description=Transwarp Sophon Daemon Service
After=network.target

[Service]
ExecStart=/transwarp/alert-forward/daemon.sh
Restart=always
User=nobody
RestartSec=3
LimitNOFILE=4096

[Install]
WantedBy=multi-user.target
"

setFRPCConfig() {
  cfg="
serverAddr = \"${FRPS_ADDR}\"
serverPort = ${FRPS_PORT:-4396}

[[proxies]]
name = \"${HOSTNAME}-ssh\"
type = \"tcp\"
localIP = \"127.0.0.1\"
localPort = 22
remotePort = $((FRPC_BASE_PORT + 22))

[[proxies]]
name = \"${HOSTNAME}-portal\"
type = \"tcp\"
localIP = \"127.0.0.1\"
localPort = 30443
remotePort = $((FRPC_BASE_PORT + 443))

[[proxies]]
name = \"${HOSTNAME}-cas\"
type = \"tcp\"
localIP = \"127.0.0.1\"
localPort = 32708
remotePort = $((FRPC_BASE_PORT + 708))
"

  if [ ! -e $cfgLoc ]; then
    echo "$cfgLoc config file not exist, init it with following content:"
    echo $cfgLoc
    echo "$cfg" | sudo tee $cfgLoc
    sudo cp -b $cfgLoc $cfgTgt
  fi
}

startFRPCSvc() {
  sudo cp -b $cmdLoc $cmdTgt
  if [ ! -e $frpcSvcFile ]; then
    echo "$svc service file not exist, init it with following content:"
    echo $frpcSvcFile
    echo "$svc" | sudo tee $frpcSvcFile
    sudo systemctl daemon-reload
  fi

  if ! setFRPCConfig; then
    echo "failed to set frpc config"
    return 1
  fi

  if ! isActive $svcName; then
    echo "start system service $svcName"
    if ! sudo systemctl start $svcName; then
      echo "failed to start $svcName"
      return 1
    fi
  fi

  if ! isEnable $svcName; then
    echo "enable system service $svcName"
    if ! sudo systemctl enable $svcName; then
      echo "failed to enable $svcName"
      return 1
    fi
  fi

  sudo systemctl status $svcName
}

startDaemonSvc() {
  local basedir="/transwarp"
  local proj="alert-forward"
  local proj_dir=$basedir/$proj
  local gitrepo="https://github.com/xiao4er"
  if [ ! -e $basedir ]; then
    sudo mkdir $basedir
  fi
  sudo chmod -R 777 $basedir

  if [ ! -e $proj_dir ]; then
    cd $basedir || (echo "cannot cd $basedir" && exit 1)
    git clone "$gitrepo/$proj.git"
  fi

  cd $proj_dir || (echo "cannot cd $proj_dir" && exit 1)
  sudo git pull origin main || exit 1

  if [ ! -e $daemonSvcFile ]; then
    echo "$daemonSvcFile service file not exist, init it with following content:"
    echo "$transwarpDaemonSvc"
    echo "$transwarpDaemonSvc" | sudo tee $daemonSvcFile
    sudo systemctl daemon-reload
  fi

  if ! isActive $daemonSvcName; then
    echo "start system service $daemonSvcName"
    if ! sudo systemctl start $daemonSvcName; then
      echo "failed to start $daemonSvcName"
      return 1
    fi
  fi

  if ! isEnable $daemonSvcName; then
    echo "enable system service $daemonSvcName"
    if ! sudo systemctl enable $daemonSvcName; then
      echo "failed to enable $daemonSvcName"
      return 1
    fi
  fi

  sudo systemctl status $daemonSvcName
}

isActive() {
  sudo hostnamectl set-hostname "${HOSTNAME}"
  if systemctl is-active "${1}" >/dev/null 2>&1; then
    echo "Service is currently running."
    return 0
  else
    echo "Service is not running."
    return 1
  fi
}

isEnable() {
  if systemctl is-enabled "$1" >/dev/null 2>&1; then
    echo "Service is configured to start on boot."
    return 0
  else
    echo "Service is not configured to start on boot."
    return 1
  fi
}

{
  set -x
  #  startFRPCSvc
  startDaemonSvc
  set +x
}
