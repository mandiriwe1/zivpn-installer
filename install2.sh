#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive

BIN="/usr/local/bin/zivpn-core"
MENU="/usr/local/bin/zivpn"
CONF="/etc/zivpn/config.json"
URL="https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-amd64"

DEFAULT_USERS='["admin","zi","zivpn","yhd"]'

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

echo "[3] Config auto fix..."
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

echo "[5] Systemd service..."
cat > /etc/systemd/system/zivpn.service <<EOF
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

echo "[6] Install FAST MENU..."

cat > $MENU <<'EOF'
#!/bin/bash

CONF="/etc/zivpn/config.json"
CACHE="/tmp/zivpn_cache"

YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
NC='\033[0m'

DEFAULT_USERS='["admin","zi","zivpn","yhd"]'

pause(){ read -p "Enter lanjut..."; }

get_cache(){
[ ! -f $CACHE ] && {
  IP=$(curl -s --max-time 2 https://api.ipify.org)
  ISP=$(timeout 2 curl -s ipinfo.io/org 2>/dev/null || echo "UNKNOWN")
  echo "$IP|$ISP" > $CACHE
}
cat $CACHE
}

cpu(){ awk '{u=$2+$4; t=$2+$3+$4+$5} END {print int((u*100)/t)}' /proc/stat; }
ram(){ free -m | awk 'NR==2{printf "%.0f%%",$3*100/$2}'; }

fix_config(){
if [ ! -f "$CONF" ] || ! jq empty "$CONF" 2>/dev/null; then
cat > "$CONF" <<EOF2
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
EOF2
fi
}

status(){
DATA=$(get_cache)
IP=$(echo $DATA | cut -d'|' -f1)
ISP=$(echo $DATA | cut -d'|' -f2)

echo -e "${GREEN}STATUS : ONLINE${NC}"
echo -e "${CYAN}IP VPS : $IP${NC}"
echo -e "${YELLOW}ISP    : $ISP${NC}"
echo -e "${GREEN}CPU    : $(cpu)%${NC}"
echo -e "${CYAN}RAM    : $(ram)${NC}"
echo ""
}

banner(){
clear
echo -e "${BLUE}==============================${NC}"
echo -e "${YELLOW}        ZIVPN PANEL${NC}"
echo -e "${BLUE}==============================${NC}"
echo ""
status
echo -e "${BLUE}==============================${NC}"
}

list_user(){
fix_config

echo ""
echo -e "${YELLOW}===== LIST AKUN =====${NC}"

users=$(jq -r '.auth.config[]?' $CONF 2>/dev/null)
[ -z "$users" ] && users=$(echo $DEFAULT_USERS | jq -r '.[]')

i=1
for u in $users; do
  echo -e "${CYAN}$i.${NC} USER : ${GREEN}$u${NC}"
  i=$((i+1))
done

echo ""
pause
}

add_user(){
fix_config
read -p "Password baru : " p
jq ".auth.config += [\"$p\"]" $CONF > /tmp/z.json && mv /tmp/z.json $CONF
systemctl restart zivpn
echo "✔ User dibuat"
pause
}

delete_user(){
fix_config
read -p "Hapus password : " d
jq --arg d "$d" '.auth.config |= map(select(. != $d))' $CONF > /tmp/z.json && mv /tmp/z.json $CONF
systemctl restart zivpn
echo "✔ User dihapus"
pause
}

restart_srv(){
systemctl restart zivpn
rm -f $CACHE
echo "✔ Restart OK"
pause
}

menu(){
while true; do
fix_config
banner

echo -e "${YELLOW}1) Create Password${NC}"
echo -e "${YELLOW}2) List Akun${NC}"
echo -e "${YELLOW}3) Delete Password${NC}"
echo -e "${YELLOW}4) Restart Server${NC}"
echo -e "${YELLOW}5) Exit${NC}"
echo ""

read -p "Pilih menu : " opt

case $opt in
1) add_user ;;
2) list_user ;;
3) delete_user ;;
4) restart_srv ;;
5) exit ;;
*) echo "Salah menu"; sleep 1 ;;
esac
done
}

menu
EOF

chmod +x $MENU

echo "[7] AUTO LOGIN..."
grep -q "zivpn" ~/.bashrc || echo '/usr/local/bin/zivpn' >> ~/.bashrc

echo ""
echo "================================"
echo " INSTALL SELESAI"
echo " ketik: zivpn"
echo "================================"
