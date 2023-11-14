#!/bin/bash

set -u

cfgLoc="./frpc.toml"
cfgTgt="/etc/frpc.toml"
cmdLoc="./frpc-arm64"
cmdTgt="/usr/local/bin/frpc-arm64"
svcName="frpc"
svcFile="/etc/systemd/system/frpc.service"
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

startFRPCSvc() {
  sudo cp -b $cmdLoc $cmdTgt
  sudo cp -b $cfgLoc $cfgTgt
  if [ ! -e $svcFile ]; then
    echo "$svc service file not exist, init it with following content:"
    echo $svcFile
    echo "$svc" | sudo tee $svcFile
    sudo systemctl daemon-reload
  fi

  if [ ! -e $cfgLoc ]; then
    echo "$cfgLoc config file not exist, init it with following content:"
    echo $cfgLoc
    echo "$cfg" | sudo tee $cfgLoc
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

  sudo systemctl status  $svcName
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
  startFRPCSvc
}