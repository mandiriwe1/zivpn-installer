#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive

BIN="/usr/local/bin/zivpn-core"
MENU="/usr/local/bin/zivpn"
CONF="/etc/zivpn/config.json"
SERVICE="/etc/systemd/system/zivpn.service"

URL="https://github.com/mandiriwe1/zivpn-installer/releases/download/Udp/udp-zivpn-linux-amd64.1"

DEFAULT_USERS='["zivpn","yhds"]'

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
