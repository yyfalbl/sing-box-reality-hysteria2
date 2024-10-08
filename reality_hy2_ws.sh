#!/bin/bash

# Function to print characters with delay
print_with_delay() {
    text="$1"
    delay="$2"
    for ((i = 0; i < ${#text}; i++)); do
        echo -n "${text:$i:1}"
        sleep $delay
    done
    echo
}
#notice
show_notice() {
    local message="$1"

    echo "#######################################################################################################################"
    echo "                                                                                                                       "
    echo "                                ${message}                                                                             "
    echo "                                                                                                                       "
    echo "#######################################################################################################################"
}
# Introduction animation
print_with_delay "sing-reality-hy2-box" 0.05
echo ""
echo ""
# install base
install_base(){
  # Check if jq is installed, and install it if not
  if ! command -v jq &> /dev/null; then
      echo "jq is not installed. Installing..."
      if [ -n "$(command -v apt)" ]; then
          apt update > /dev/null 2>&1
          apt install -y jq > /dev/null 2>&1
      elif [ -n "$(command -v yum)" ]; then
          yum install -y epel-release
          yum install -y jq
      elif [ -n "$(command -v dnf)" ]; then
          dnf install -y jq
      else
          echo "Cannot install jq. Please install jq manually and rerun the script."
          exit 1
      fi
  fi
}
# regenrate cloudflared argo
regenarte_cloudflared_argo(){
  pid=$(pgrep -f cloudflared)
  if [ -n "$pid" ]; then
    # 终止进程
    kill "$pid"
  fi

  vmess_port=$(jq -r '.inbounds[2].listen_port' /root/sbox/sbconfig_server.json)
  #生成地址
  /root/sbox/cloudflared-linux tunnel --url http://localhost:$vmess_port --no-autoupdate --edge-ip-version auto --protocol h2mux>argo.log 2>&1 &
  sleep 2
  clear
  echo 等待cloudflare argo生成地址
  sleep 5
  #连接到域名
  argo=$(cat argo.log | grep trycloudflare.com | awk 'NR==2{print}' | awk -F// '{print $2}' | awk '{print $1}')
  echo "$argo" | base64 > /root/sbox/argo.txt.b64
  rm -rf argo.log

  }
# download singbox and cloudflared
download_singbox(){
  arch=$(uname -m)
  echo "Architecture: $arch"
  # Map architecture names
  case ${arch} in
      x86_64)
          arch="amd64"
          ;;
      aarch64)
          arch="arm64"
          ;;
      armv7l)
          arch="armv7"
          ;;
  esac
  # Fetch the latest (including pre-releases) release version number from GitHub API
  # 正式版
  #latest_version_tag=$(curl -s "https://api.github.com/repos/SagerNet/sing-box/releases" | grep -Po '"tag_name": "\K.*?(?=")' | head -n 1)
  #beta版本
  latest_version_tag=$(curl -s "https://api.github.com/repos/SagerNet/sing-box/releases" | grep -Po '"tag_name": "\K.*?(?=")' | sort -V | tail -n 1)
  latest_version=${latest_version_tag#v}  # Remove 'v' prefix from version number
  echo "Latest version: $latest_version"
  # Detect server architecture
  # Prepare package names
  package_name="sing-box-${latest_version}-linux-${arch}"
  # Prepare download URL
  url="https://github.com/SagerNet/sing-box/releases/download/${latest_version_tag}/${package_name}.tar.gz"
  # Download the latest release package (.tar.gz) from GitHub
  curl -sLo "/root/${package_name}.tar.gz" "$url"

  # Extract the package and move the binary to /root
  tar -xzf "/root/${package_name}.tar.gz" -C /root
  mv "/root/${package_name}/sing-box" /root/sbox

  # Cleanup the package
  rm -r "/root/${package_name}.tar.gz" "/root/${package_name}"

  # Set the permissions
  chown root:root /root/sbox/sing-box
  chmod +x /root/sbox/sing-box
}

# download singbox and cloudflared
download_cloudflared(){
  arch=$(uname -m)
  # Map architecture names
  case ${arch} in
      x86_64)
          cf_arch="amd64"
          ;;
      aarch64)
          cf_arch="arm64"
          ;;
      armv7l)
          cf_arch="arm"
          ;;
  esac

  # install cloudflared linux
  cf_url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${cf_arch}"
  curl -sLo "/root/sbox/cloudflared-linux" "$cf_url"
  chmod +x /root/sbox/cloudflared-linux
  echo ""
}


# client configuration
show_client_configuration() {
  # Get current listen port
  current_listen_port=$(jq -r '.inbounds[0].listen_port' /root/sbox/sbconfig_server.json)
  # Get current server name
  current_server_name=$(jq -r '.inbounds[0].tls.server_name' /root/sbox/sbconfig_server.json)
  # Get the UUID
  uuid=$(jq -r '.inbounds[0].users[0].uuid' /root/sbox/sbconfig_server.json)
  # Get the public key from the file, decoding it from base64
  public_key=$(base64 --decode /root/sbox/public.key.b64)
  # Get the short ID
  short_id=$(jq -r '.inbounds[0].tls.reality.short_id[0]' /root/sbox/sbconfig_server.json)
  # Retrieve the server IP address
  server_ip=$(curl -s4m8 ip.sb -k) || server_ip=$(curl -s6m8 ip.sb -k)
  echo ""
  show_notice "Reality 客户端通用链接" 
  echo ""
  server_link="vless://$uuid@$server_ip:$current_listen_port?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$current_server_name&fp=chrome&pbk=$public_key&sid=$short_id&type=tcp&headerType=none#SING-BOX-Reality"
  echo ""
  echo "$server_link"
  echo ""
  # Get current listen port
  hy_current_listen_port=$(jq -r '.inbounds[1].listen_port' /root/sbox/sbconfig_server.json)
  # Get current server name
  hy_current_server_name=$(openssl x509 -in /root/self-cert/cert.pem -noout -subject -nameopt RFC2253 | awk -F'=' '{print $NF}')
  # Get the password
  hy_password=$(jq -r '.inbounds[1].users[0].password' /root/sbox/sbconfig_server.json)
  # Generate the link  
  hy2_server_link="hysteria2://$hy_password@$server_ip:$hy_current_listen_port?insecure=1&sni=$hy_current_server_name"

  show_notice "Hysteria2 客户端通用链接" 
  echo ""
  echo "官方 hysteria2通用链接格式"
  echo ""
  echo "$hy2_server_link"
  echo ""
  
  argo=$(base64 --decode /root/sbox/argo.txt.b64)
  vmess_uuid=$(jq -r '.inbounds[2].users[0].uuid' /root/sbox/sbconfig_server.json)
  ws_path=$(jq -r '.inbounds[2].transport.path' /root/sbox/sbconfig_server.json)
  show_notice "vmess ws 通用链接参数" 
  echo ""
  echo "以下为vmess链接，替换speed.cloudflare.com为自己的优选ip可获得极致体验"
  echo ""
  echo 'vmess://'$(echo '{"add":"speed.cloudflare.com","aid":"0","host":"'$argo'","id":"'$vmess_uuid'","net":"ws","path":"'$ws_path'","port":"443","ps":"sing-box-vmess-tls","tls":"tls","type":"none","v":"2"}' | base64 -w 0)
  echo ""
  echo -e "端口 443 可改为 2053 2083 2087 2096 8443"
  echo ""
  echo 'vmess://'$(echo '{"add":"speed.cloudflare.com","aid":"0","host":"'$argo'","id":"'$vmess_uuid'","net":"ws","path":"'$ws_path'","port":"80","ps":"sing-box-vmess","tls":"","type":"none","v":"2"}' | base64 -w 0)
  echo ""
  echo -e "端口 80 可改为 8080 8880 2052 2082 2086 2095" 
  echo ""
}
uninstall_singbox() {
            echo "Uninstalling..."
          # Stop and disable sing-box service
          systemctl stop sing-box
          systemctl disable sing-box > /dev/null 2>&1

          # Remove files
          rm /etc/systemd/system/sing-box.service
          rm /root/sbox/sbconfig_server.json
          rm /root/sbox/sing-box
          rm /root/sbox/cloudflared-linux
          rm /root/sbox/argo.txt.b64
          rm /root/sbox/public.key.b64
          rm /root/self-cert/private.key
          rm /root/self-cert/cert.pem
          rm -rf /root/self-cert/
          rm -rf /root/sbox/
          echo "DONE!"
}
install_base
install_singbox() {

    echo "开始配置 Reality"
    echo ""

    # 自动生成基本参数
    key_pair=$(/root/sbox/sing-box generate reality-keypair)
    if [ $? -ne 0 ]; then
        echo "生成 Reality 密钥对失败。"
        exit 1
    fi

    # 提取私钥和公钥
    private_key=$(echo "$key_pair" | awk '/PrivateKey/ {print $2}' | tr -d '"')
    public_key=$(echo "$key_pair" | awk '/PublicKey/ {print $2}' | tr -d '"')

    # 将公钥以 base64 编码保存到文件
    echo "$public_key" | base64 > /root/sbox/public.key.b64

    # 生成必要的值
    uuid=$(/root/sbox/sing-box generate uuid)
    short_id=$(/root/sbox/sing-box generate rand --hex 8)
    echo "UUID 和短 ID 生成完成"
    echo ""

    # 获取用户输入监听端口
    read -p "请输入 Reality 端口 (default: 443): " listen_port
    listen_port=${listen_port:-443}
    echo ""

    # 获取服务器名称 (SNI)
    read -p "请输入想要使用的域名 (default: itunes.apple.com): " server_name
    server_name=${server_name:-itunes.apple.com}
    echo ""

    # 开始配置 Hysteria2
    echo "开始配置 Hysteria2"
    echo ""

    # 生成 Hysteria 需要的值
    hy_password=$(/root/sbox/sing-box generate rand --hex 8)

    # 获取 Hysteria 监听端口
    read -p "请输入 Hysteria2 监听端口 (default: 8443): " hy_listen_port
    hy_listen_port=${hy_listen_port:-8443}
    echo ""

    # 获取自签名证书的域名
    read -p "输入自签证书域名 (default: bing.com): " hy_server_name
    hy_server_name=${hy_server_name:-bing.com}

    # 生成自签名证书
    mkdir -p /root/self-cert/
    openssl ecparam -genkey -name prime256v1 -out /root/self-cert/private.key
    openssl req -new -x509 -days 36500 -key /root/self-cert/private.key -out /root/self-cert/cert.pem -subj "/CN=${hy_server_name}"
    echo ""
    echo "自签证书生成完成"
    echo ""

    # 开始配置 VMess
    echo "开始配置 VMess"
    echo ""

    # 生成 VMess 需要的值
    vmess_uuid=$(/root/sbox/sing-box generate uuid)
    read -p "请输入 VMess 端口，默认为 15555: " vmess_port
    vmess_port=${vmess_port:-15555}
    echo ""

    read -p "ws 路径 (默认随机生成): " ws_path
    ws_path=${ws_path:-$(/root/sbox/sing-box generate rand --hex 6)}

    # 检查并终止 cloudflared 进程
    pid=$(pgrep -f cloudflared)
    if [ -n "$pid" ]; then
        # 终止进程
        kill "$pid"
    fi

    # 生成 Argo 地址
    /root/sbox/cloudflared-linux tunnel --url http://localhost:$vmess_port --no-autoupdate --edge-ip-version auto --protocol h2mux > argo.log 2>&1 &
    sleep 2
    clear
    echo "等待 Cloudflare Argo 生成地址..."
    sleep 5

    # 连接到域名
    argo=$(cat argo.log | grep trycloudflare.com | awk 'NR==2{print}' | awk -F// '{print $2}' | awk '{print $1}')
    echo "$argo" | base64 > /root/sbox/argo.txt.b64
    rm -rf argo.log

    # 获取服务器 IP 地址
    server_ip=$(curl -s4m8 ip.sb -k) || server_ip=$(curl -s6m8 ip.sb -k)

    # 使用 jq 创建 reality.json
    jq -n --arg listen_port "$listen_port" \
          --arg vmess_port "$vmess_port" \
          --arg vmess_uuid "$vmess_uuid" \
          --arg ws_path "$ws_path" \
          --arg server_name "$server_name" \
          --arg private_key "$private_key" \
          --arg short_id "$short_id" \
          --arg uuid "$uuid" \
          --arg hy_listen_port "$hy_listen_port" \
          --arg hy_password "$hy_password" \
          --arg server_ip "$server_ip" '{
      "log": {
          "disabled": false,
          "level": "info",
          "timestamp": true
      },
      "inbounds": [
          {
              "type": "vless",
              "tag": "vless-in",
              "listen": "::",
              "listen_port": ($listen_port | tonumber),
              "users": [
                  {
                      "uuid": $uuid,
                      "flow": "xtls-rprx-vision"
                  }
              ],
              "tls": {
                  "enabled": true,
                  "server_name": $server_name,
                  "reality": {
                      "enabled": true,
                      "handshake": {
                          "server": $server_name,
                          "server_port": 443
                      },
                      "private_key": $private_key,
                      "short_id": [$short_id]
                  }
              }
          },
          {
              "type": "hysteria2",
              "tag": "hy2-in",
              "listen": "::",
              "listen_port": ($hy_listen_port | tonumber),
              "users": [
                  {
                      "password": $hy_password
                  }
              ],
              "tls": {
                  "enabled": true,
                  "alpn": [
                      "h3"
                  ],
                  "certificate_path": "/root/self-cert/cert.pem",
                  "key_path": "/root/self-cert/private.key"
              }
          },
          {
              "type": "vmess",
              "tag": "vmess-in",
              "listen": "::",
              "listen_port": ($vmess_port | tonumber),
              "users": [
                  {
                      "uuid": $vmess_uuid,
                      "alterId": 0
                  }
              ],
              "transport": {
                  "type": "ws",
                  "path": $ws_path
              }
          }
      ],
      "outbounds": [
          {
              "type": "direct",
              "tag": "direct"
          },
          {
              "type": "block",
              "tag": "block"
          }
      ]
  }' > /root/sbox/sbconfig_server.json

    echo "配置文件已生成：/root/sbox/sbconfig_server.json"
}

echo "sing-box-reality-hysteria2已经安装"
echo ""
echo "请选择选项:"
echo "1. 安装sing-box服务"
echo "2. 重新安装"
echo "3. 修改配置"
echo "4. 显示客户端配置"
echo "5. 卸载"
echo "6. 更新sing-box内核"
echo "7. 手动重启cloudflared"
echo "0. 退出脚本"
read -p "Enter your choice (0-7): " choice

case $choice in
    1)
        echo "开始安装sing-box服务..."
          mkdir -p "/root/sbox/"
         download_singbox
        download_cloudflared
        install_singbox
        ;;
    2)
        show_notice "重新安装中..."
        systemctl stop sing-box
        systemctl disable sing-box > /dev/null 2>&1
        rm /etc/systemd/system/sing-box.service
        rm /root/sbox/sbconfig_server.json
        rm /root/sbox/sing-box
        rm /root/sbox/cloudflared-linux
        rm /root/sbox/argo.txt.b64
        rm /root/sbox/public.key.b64
        rm -rf /root/self-cert/
        rm -rf /root/sbox/
        
        # 重新安装的步骤
        install_singbox
        ;;
    3)
        show_notice "开始修改reality端口和域名"
        current_listen_port=$(jq -r '.inbounds[0].listen_port' /root/sbox/sbconfig_server.json)
        read -p "请输入想要修改的端口号 (当前端口为 $current_listen_port): " listen_port
        listen_port=${listen_port:-$current_listen_port}
        
        current_server_name=$(jq -r '.inbounds[0].tls.server_name' /root/sbox/sbconfig_server.json)
        read -p "请输入想要使用的h2域名 (当前域名为 $current_server_name): " server_name
        server_name=${server_name:-$current_server_name}

        show_notice "开始修改hysteria2端口"
        hy_current_listen_port=$(jq -r '.inbounds[1].listen_port' /root/sbox/sbconfig_server.json)
        read -p "请输入想要修改的端口 (当前端口为 $hy_current_listen_port): " hy_listen_port
        hy_listen_port=${hy_listen_port:-$hy_current_listen_port}

        jq --arg listen_port "$listen_port" --arg server_name "$server_name" --arg hy_listen_port "$hy_listen_port" \
            '.inbounds[1].listen_port = ($hy_listen_port | tonumber) | .inbounds[0].listen_port = ($listen_port | tonumber) | .inbounds[0].tls.server_name = $server_name | .inbounds[0].tls.reality.handshake.server = $server_name' \
            /root/sbox/sbconfig_server.json > /root/sb_modified.json

        mv /root/sb_modified.json /root/sbox/sbconfig_server.json

        echo "配置修改完成，重新启动sing-box服务..."
        systemctl restart sing-box
        show_client_configuration
        exit 0
        ;;
    4)  
        show_client_configuration
        exit 0
        ;;	
    5)
        uninstall_singbox
        exit 0
        ;;
    6)
        show_notice "更新 Sing-box..."
        download_singbox
        if /root/sbox/sing-box check -c /root/sbox/sbconfig_server.json; then
            echo "配置检查成功，启动sing-box服务..."
            systemctl daemon-reload
            systemctl enable sing-box > /dev/null 2>&1
            systemctl start sing-box
            systemctl restart sing-box
        fi
        echo ""
        exit 1
        ;;
    7)
        regenarte_cloudflared_argo
        echo "重新启动完成，查看新的vmess客户端信息"
        show_client_configuration
        exit 1
        ;;
    0)
        echo "已退出脚本"
        exit 0
        ;;
    *)
        echo "无效选项。正在退出。"
        exit 1
        ;;
esac

# Create sing-box.service
cat > /etc/systemd/system/sing-box.service <<EOF
[Unit]
After=network.target nss-lookup.target

[Service]
User=root
WorkingDirectory=/root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
ExecStart=/root/sbox/sing-box run -c /root/sbox/sbconfig_server.json
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=10
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF


# Check configuration and start the service
if /root/sbox/sing-box check -c /root/sbox/sbconfig_server.json; then
    echo "Configuration checked successfully. Starting sing-box service..."
    systemctl daemon-reload
    systemctl enable sing-box > /dev/null 2>&1
    systemctl start sing-box
    systemctl restart sing-box

    show_client_configuration


else
    echo "Error in configuration. Aborting"
fi
