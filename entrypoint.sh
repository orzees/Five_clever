#!/bin/bash

# 设置各变量
WSPATH=${WSPATH:-'argo'}
UUID=${UUID:-'8192f723-6b17-4edc-a109-ff21cdec461b'}

# 其他Paas保活
PAAS1_URL=
PAAS2_URL=
PAAS3_URL=
PAAS4_URL=
PAAS5_URL=
PAAS6_URL=

# koyeb账号保活
KOYEB_ACCOUNT=
KOYEB_PASSWORD=

# Argo 固定域名隧道的两个参数,这个可以填 Json 内容或 Token 内容，获取方式看 https://github.com/fscarmen2/X-for-Glitch，不需要的话可以留空，删除或在这三行最前面加 # 以注释
ARGO_AUTH=''
ARGO_DOMAIN=


generate_web() {
# 下载并运行 web
  cat > web.sh << EOF
#!/usr/bin/env bash

check_file() {
  [ ! -e web.js ] && wget -O web.js https://raw.githubusercontent.com/numia090/paas/master/web
}

run() {
  chmod +x web.js && ./web.js >/dev/null 2>&1 &
}

check_file
run
EOF
}


generate_argo() {
  cat > argo.sh << ABC
#!/usr/bin/env bash

ARGO_AUTH=${ARGO_AUTH}
ARGO_DOMAIN=${ARGO_DOMAIN}

# 下载并运行 Argo
check_file() {
  [ ! -e cloudflared ] && wget -O cloudflared https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 && chmod +x cloudflared
}

run() {
    ./cloudflared tunnel --edge-ip-version auto --no-autoupdate --logfile argo.log --loglevel info --url http://localhost:8080 2>&1 &
    sleep 5
    ARGO_DOMAIN=\$(cat argo.log | grep -o "info.*https://.*trycloudflare.com" | sed "s@.*https://@@g" | tail -n 1)
}

export_list() {
  VMESS="{ \"v\": \"2\", \"ps\": \"Argo-Vmess\", \"add\": \"icook.hk\", \"port\": \"443\", \"id\": \"${UUID}\", \"aid\": \"0\", \"scy\": \"none\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"\${ARGO_DOMAIN}\", \"path\": \"/vmess\", \"tls\": \"tls\", \"sni\": \"\${ARGO_DOMAIN}\", \"alpn\": \"\" }"
  cat > list << EOF
*******************************************
V2-rayN:
----------------------------
vless://${UUID}@icook.hk:443?encryption=none&security=tls&sni=\${ARGO_DOMAIN}&type=ws&host=\${ARGO_DOMAIN}&path=%2Fvless#Argo-Vless
----------------------------
vmess://\$(echo \$VMESS | base64 -w0)
----------------------------
trojan://${UUID}@icook.hk:443?security=tls&sni=\${ARGO_DOMAIN}&type=ws&host=\${ARGO_DOMAIN}&path=%2Ftrojan#Argo-Trojan
----------------------------

EOF
  cat list
}
check_file
run
export_list
ABC
}

# Paas保活
generate_keeplive() {
  cat > paaslive.sh << EOF
#!/usr/bin/env bash

# 传参
PAAS1_URL=${PAAS1_URL}
PAAS2_URL=${PAAS2_URL}
PAAS3_URL=${PAAS3_URL}
PAAS4_URL=${PAAS4_URL}
PAAS5_URL=${PAAS5_URL}
PAAS6_URL=${PAAS6_URL}

# 判断变量并保活

if [[ -z "\${PAAS1_URL}" && -z "\${PAAS2_URL}" && -z "\${PAAS3_URL}" && -z "\${PAAS4_URL}" && -z "\${PAAS5_URL}" && -z "\${PAAS6_URL}" ]]; then
    echo "所有变量都不存在，程序退出。"
    exit 1
fi

function handle_error() {
    # 处理错误函数
    echo "连接超时"
    sleep 10
}

while true; do
    for var in 1 2 3 4 5 6
    do
        url_var="PAAS\${var}_URL"
        url=\${!url_var}
        if [[ -n "\${url}" ]]; then
            count=0
            while true; do
                curl -k --connect-timeout 10 "\${url}" || (handle_error;continue)
                    break
            done
        fi
    done
    sleep 20m
done
EOF
}

# koyeb保活
generate_koyeb() {
  cat > koyeb.sh << EOF
#!/usr/bin/env bash

# 传参
KOYEB_ACCOUNT=${KOYEB_ACCOUNT}
KOYEB_PASSWORD=${KOYEB_PASSWORD}

# 两个变量不全则不运行保活
check_variable() {
  [[ -z "\${KOYEB_ACCOUNT}" || -z "\${KOYEB_ACCOUNT}" ]] && exit
}

# 开始保活
run() {
while true
do
  curl -sX POST https://app.koyeb.com/v1/account/login -H 'Content-Type: application/json' -d '{"email":"'"\${KOYEB_ACCOUNT}"'","password":"'"\${KOYEB_PASSWORD}"'"}'
  rm -rf /dev/null
  sleep $((60*60*24*5))
done
}
check_variable
run
EOF
}

generate_config
generate_web
generate_argo
generate_keeplive
generate_koyeb
[ -e web.sh ] && nohup bash web.sh >/dev/null 2>&1 &
[ -e argo.sh ] && nohup bash argo.sh >/dev/null 2>&1 &
[ -e paaslive.sh ] && nohup bash paaslive.sh >/dev/null 2>&1 &
[ -e koyeb.sh ] && nohup bash koyeb.sh >/dev/null 2>&1 &
