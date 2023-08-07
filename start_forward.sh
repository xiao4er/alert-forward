#!/bin/bash


HOST=${HOST:-"localhost"}
PORT=${PORT:-"31883"}
DATA_STORE=${DATA_STORE:-"/mnt/disk1/autocv/data/autocv/vision/store/images"}

cmdLoc="./alt-forward-arm64"
cmdTgt="/usr/local/bin/alt-forward-arm64"
logTgt="/var/log/alt-forward.log"
svcName="alt-forward"
svcFile="/etc/systemd/system/alt-forward.service"
svc="
[Unit]
Description=Sophon Edge Alert Forwarding Service
After=network.target

[Service]
ExecStart=${cmdTgt}
StandardOutput=append:${logTgt}
StandardError=append:${logTgt}
Restart=always
Environment=\"HOST=${HOST}\" \"PORT=${PORT}\" \"DATA_STORE=${DATA_STORE}\"

[Install]
WantedBy=default.target
"

startAltForwardSvc() {
  sudo cp $cmdLoc $cmdTgt
  sudo touch /var/log/alt-forward.log
  if [ ! -e $svcFile ]; then
    echo "$svc service file not exist, init it with following content:"
    echo $svcFile
    echo "$svc" | sudo tee $svcFile
    sudo systemctl daemon-reload
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
  startAltForwardSvc
}