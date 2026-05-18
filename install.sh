#!/bin/bash
# Zivpn UDP Module installer
# Creator  Yhds Zivpn

echo -e "Updating server"

sudo apt-get update && sudo apt-get upgrade -y

systemctl stop zivpn.service 1> /dev/null 2> /dev/null

echo -e "Downloading UDP Service"

REPO="mandiriwe1/udp-zivpn"
VERSION="udp-zivpn_1.4.9"

wget -O /usr/local/bin/zivpn \
https://github.com/$REPO/releases/download/$VERSION/udp-zivpn-linux-amd64 \
1> /dev/null 2> /dev/null

chmod +x /usr/local/bin/zivpn

mkdir -p /etc/zivpn 1> /dev/null 2> /dev/null

wget -O /etc/zivpn/config.json \
https://raw.githubusercontent.com/$REPO/main/config.json \
1> /dev/null 2> /dev/null

echo "Generating cert files:"
openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 -subj "/C=US/ST=California/L=Los Angeles/O=Example Corp/OU=IT Department/CN=zivpn" -keyout "/etc/zivpn/zivpn.key" -out "/etc/zivpn/zivpn.crt"
sysctl -w net.core.rmem_max=16777216 1> /dev/null 2> /dev/null
sysctl -w net.core.wmem_max=16777216 1> /dev/null 2> /dev/null
cat <<EOF > /etc/systemd/system/zivpn.service
[Unit]
Description=zivpn VPN Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/etc/zivpn
ExecStart=/usr/local/bin/zivpn server -c /etc/zivpn/config.json
Restart=always
RestartSec=3
Environment=ZIVPN_LOG_LEVEL=info
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF

echo -e "ZIVPN UDP Passwords"
read -p "Enter passwords separated by commas, example: pass1,pass2 (Press enter for Default 'zivpn'): " input_config scip

if [ -n "$input_config" ]; then
    IFS=',' read -r -a config <<< "$input_config"
    if [ ${#config[@]} -eq 1 ]; then
        config+=(${config[0]})
    fi
else
    config=("zivpn")
fi

new_config_str="\"config\": [$(printf "\"%s\"," "${config[@]}" | sed 's/,$//')]"

sed -i -E "s/\"config\": ?\[[[:space:]]*\"zivpn\"[[:space:]]*\]/${new_config_str}/g" /etc/zivpn/config.json


systemctl enable zivpn.service
systemctl start zivpn.service
iptables -t nat -A PREROUTING -i $(ip -4 route ls|grep default|grep -Po '(?<=dev )(\S+)'|head -1) -p udp --dport 6000:19999 -j DNAT --to-destination :5667
ufw allow 6000:19999/udp
ufw allow 5667/udp
rm zi.* 1> /dev/null 2> /dev/null
echo -e "ZIVPN UDP Installed"

#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive

BIN="/usr/local/bin/zivpn-core"
MENU="/usr/local/bin/zivpn"
CONF="/etc/zivpn/config.json"
SERVICE="/etc/systemd/system/zivpn.service"

URL="https://github.com/mandiriwe1/zivpn-installer/releases/download/Udp/udp-zivpn-linux-amd64"

DEFAULT_USERS='["zivpn"]'

echo "[1] Install dependencies..."
apt-get update -y >/dev/null 2>&1
apt-get install -y wget curl jq openssl iptables ufw iproute2 procps >/dev/null 2>&1

mkdir -p /etc/zivpn

echo "[2] Download binary..."
for i in 1 2 3 4 5; do
  wget -q --timeout=15 "$URL" -O "$BIN" && break
  sleep 2
done

chmod +x "$BIN"

[ ! -s "$BIN" ] && echo "Binary gagal download" && exit 1

echo "[3] Config setup..."
cat > "$CONF" <<EOF
{
  "listen": ":5667",
  "cert": "/etc/zivpn/zivpn.crt",
  "key": "/etc/zivpn/zivpn.key",
  "obfs": "zivpn",
  "auth": {
    "mode": "passwords",
    "config": $DEFAULT_USERS
  }
}
EOF

echo "[4] SSL generate..."
openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 \
-subj "/CN=ZIVPN" \
-keyout /etc/zivpn/zivpn.key \
-out /etc/zivpn/zivpn.crt >/dev/null 2>&1

echo "[5] System service..."
cat > "$SERVICE" <<EOF
[Unit]
Description=ZIVPN Server
After=network.target

[Service]
ExecStart=$BIN server -c $CONF
Restart=always
User=root
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable zivpn
systemctl restart zivpn

echo "[6] Install MENU..."

cat > "$MENU" <<'EOF'
#!/bin/bash

CONF="/etc/zivpn/config.json"
CACHE="/tmp/zivpn_cache"

fix_config(){
[ ! -f "$CONF" ] && return
jq empty "$CONF" 2>/dev/null || echo "config error"
}

status(){
echo -e "\e[0m"
echo -e "\e[36m"
cat << "EOF2"
 _   _ ____  ____    __________     ______  _   _
| | | |  _ \|  _ \  |__  /_ _\ \   / /  _ \| \ | |
| | | | | | | |_) |   / / | | \ \ / /| |_) |  \| |
| |_| | |_| |  __/   / /_ | |  \ V / |  __/| |\  |
 \___/|____/|_|     /____|___|  \_/  |_|   |_| \_|
EOF2
echo -e "\e[0m"

IP=$(hostname -I | awk '{print $1}')
ISP=$(curl -s ipinfo.io/org)
CPU=$(grep -m1 "model name" /proc/cpuinfo | cut -d ":" -f2 | xargs)
RAM_USED=$(free -m | awk '/Mem:/ {print $3}')
RAM_TOTAL=$(free -m | awk '/Mem:/ {print $2}')
ZIVPN_STATUS=$(systemctl is-active zivpn 2>/dev/null)

PURPLE="\e[35m"
PINK="\e[95m"
GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

echo -e "${PINK}        Z I V P N ${PURPLE}- SERVER PREMIUM${RESET}"
echo -e "${PURPLE}     Secure • Fast • Stable VPN System${RESET}"

if [ "$ZIVPN_STATUS" = "active" ]; then
  STATUS="${GREEN}ONLINE${RESET}"
else
  STATUS="${RED}OFFLINE${RESET}"
fi

echo -e "${PURPLE}────────────────────────────────────────${RESET}"
echo -e "${PINK}STATUS : ${STATUS}${RESET}"
echo -e "${PURPLE}IP     : ${PINK}$IP${RESET}"
echo -e "${PURPLE}ISP    : ${PINK}$ISP${RESET}"
echo -e "${PURPLE}CPU    : ${PINK}$CPU${RESET}"
echo -e "${PURPLE}RAM    : ${PINK}${RAM_USED}MB / ${RAM_TOTAL}MB${RESET}"
echo -e "${PURPLE}────────────────────────────────────────${RESET}"
}

menu(){
while true; do
clear
status

YELLOW="\e[33m"
RESET="\e[0m"

echo -e "${YELLOW}1) Create Password${RESET}"
echo -e "${YELLOW}2) List User${RESET}"
echo -e "${YELLOW}3) Delete Password${RESET}"
echo -e "${YELLOW}4) Restart Server${RESET}"
echo -e "${YELLOW}5) Exit${RESET}"

read -p "Pilih menu : " opt

case $opt in
1)
read -p "Password baru : " p
jq ".auth.config += [\"$p\"]" $CONF > /tmp/z.json && mv /tmp/z.json $CONF
systemctl restart zivpn
echo "✔ User dibuat"; sleep 1
;;
2)
echo "=== LIST USER ==="
jq -r '.auth.config[]?' $CONF
read -p "Enter..." ;;
3)
read -p "Hapus password : " d
jq --arg d "$d" '.auth.config |= map(select(. != $d))' $CONF > /tmp/z.json && mv /tmp/z.json $CONF
systemctl restart zivpn
echo "✔ User dihapus"; sleep 1
;;
4)
systemctl restart zivpn
echo "✔ Restart OK"; sleep 1
;;
5)
exit ;;
*) echo "Salah"; sleep 1 ;;
esac
done
}

menu
EOF

chmod +x $MENU

echo "[7] AUTO START MENU..."
grep -q "zivpn" ~/.bashrc || echo "/usr/local/bin/zivpn" >> ~/.bashrc

echo ""
echo "================================"
echo " ZIVPN INSTALL SELESAI"
echo " ketik: zivpn"
echo "================================"
