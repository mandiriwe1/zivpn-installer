#!/bin/bash
# ZIVPN INSTALLER + FAST MENU (FINAL)
set -e
export DEBIAN_FRONTEND=noninteractive

BIN="/usr/local/bin/zivpn-core"
MENU="/usr/local/bin/zivpn"
CONF="/etc/zivpn/config.json"

# GITHUB RELEASE KAMU
URL="https://github.com/mandiriwe1/zivpn-installer/releases/download/Udp/udp-zivpn-linux-amd64.1"

DEFAULT_USERS='["admin","zi","zivpn","yhd"]'

clear
echo "[1/7] Install dependencies..."
apt-get update -y >/dev/null 2>&1
apt-get install -y \
wget curl jq openssl iptables ufw \
iproute2 procps file >/dev/null 2>&1

mkdir -p /etc/zivpn

echo "[2/7] Download binary..."

for i in 1 2 3 4 5; do
    wget --tries=1 --timeout=20 -qO "$BIN" "$URL" && break
    sleep 2
done

chmod +x "$BIN"

# VALIDASI BINARY (ANTI HTML / 404)
if ! file "$BIN" | grep -qi "ELF"; then
    echo ""
    echo "❌ Binary invalid / gagal download"
    echo "Cek GitHub Release:"
    echo "$URL"
    rm -f "$BIN"
    exit 1
fi

echo "[3/7] Generate config..."

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

echo "[4/7] Generate SSL..."

openssl req -new -newkey rsa:2048 \
-days 365 -nodes -x509 \
-subj "/CN=ZIVPN" \
-keyout /etc/zivpn/zivpn.key \
-out /etc/zivpn/zivpn.crt >/dev/null 2>&1

echo "[5/7] Create service..."

cat > /etc/systemd/system/zivpn.service <<EOF
[Unit]
Description=ZIVPN UDP Server
After=network.target

[Service]
ExecStart=$BIN server -c $CONF
Restart=always
RestartSec=3
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable zivpn >/dev/null 2>&1
systemctl restart zivpn

echo "[6/7] Install menu..."

cat > "$MENU" << 'EOF'
#!/bin/bash

CONF="/etc/zivpn/config.json"
CACHE="/tmp/zivpn_cache"

YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
WHITE='\033[1;37m'
NC='\033[0m'

DEFAULT_USERS='["admin","zi","zivpn","yhd"]'

pause(){
read -p "Enter lanjut..."
}

# =========================
# CACHE
# =========================
get_cache(){
if [ ! -f "$CACHE" ]; then
IP=$(curl -s --max-time 2 https://api.ipify.org)
ISP=$(timeout 2 curl -s ipinfo.io/org 2>/dev/null || echo "UNKNOWN")
echo "$IP|$ISP" > "$CACHE"
fi

cat "$CACHE"
}

# =========================
# SYSTEM INFO
# =========================
cpu(){
top -bn1 | awk '/Cpu/ {print int($2+$4)}'
}

ram(){
free -m | awk 'NR==2{printf "%.0f%%",$3*100/$2}'
}

upt(){
uptime -p 2>/dev/null
}

# =========================
# FIX CONFIG
# =========================
fix_config(){
if [ ! -f "$CONF" ] || ! jq empty "$CONF" >/dev/null 2>&1; then

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

# =========================
# STATUS
# =========================
status_panel(){

DATA=$(get_cache)

IP=$(echo "$DATA" | cut -d'|' -f1)
ISP=$(echo "$DATA" | cut -d'|' -f2)

if systemctl is-active --quiet zivpn; then
STATUS="${GREEN}ONLINE${NC}"
else
STATUS="${RED}OFFLINE${NC}"
fi

echo -e "${WHITE}STATUS : ${STATUS}"
echo -e "${WHITE}IP VPS : ${CYAN}$IP${NC}"
echo -e "${WHITE}ISP    : ${YELLOW}$ISP${NC}"
echo -e "${WHITE}UPTIME : ${CYAN}$(upt)${NC}"
echo -e "${WHITE}CPU    : ${GREEN}$(cpu)%${NC}"
echo -e "${WHITE}RAM    : ${CYAN}$(ram)${NC}"
echo ""
}

# =========================
# BANNER
# =========================
banner(){
clear

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}          YHD ZIVPN${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

status_panel

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# =========================
# USER MENU
# =========================
list_user(){

fix_config

echo ""
echo -e "${YELLOW}===== LIST AKUN =====${NC}"
echo ""

users=$(jq -r '.auth.config[]?' "$CONF" 2>/dev/null)

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

jq ".auth.config += [\"$p\"]" "$CONF" \
> /tmp/zivpn.json

mv /tmp/zivpn.json "$CONF"

systemctl restart zivpn

echo ""
echo "✔ Password berhasil dibuat"
pause
}

delete_user(){

fix_config

read -p "Hapus password : " d

jq --arg d "$d" \
'.auth.config |= map(select(. != $d))' \
"$CONF" > /tmp/zivpn.json

mv /tmp/zivpn.json "$CONF"

systemctl restart zivpn

echo ""
echo "✔ Password berhasil dihapus"
pause
}

restart_server(){

systemctl restart zivpn
rm -f "$CACHE"

echo ""
echo "✔ Server restarted"
pause
}

# =========================
# MENU
# =========================
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
4) restart_server ;;
5) clear ; exit ;;
*) echo "Menu salah" ; sleep 1 ;;
esac

done
}

menu
EOF

chmod +x "$MENU"

echo "[7/7] Enable auto menu..."

grep -q "/usr/local/bin/zivpn" ~/.bashrc || \
echo '/usr/local/bin/zivpn' >> ~/.bashrc

clear
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " INSTALL BERHASIL"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Command menu:"
echo "zivpn"
echo ""
echo "Service:"
echo "systemctl status zivpn"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
