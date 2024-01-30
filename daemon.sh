#!/bin/bash

#!/bin/bash

# 定义一个函数，用于执行所有操作
set -x
while true; do
    cd /transwarp/alert-forward || (echo cannot cd gitrepo && exit 1)
    # 执行 git pull 来更新代码
    echo "Updating project code..."
    sudo git pull origin main

    # 执行 upgrade.sh 脚本
    echo "Executing upgrade.sh script..."
    sudo ./auto-upgrade.sh
    sleep 7200

done
set +x