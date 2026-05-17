#!/bin/bash
# YHDS ZIVPN FULL PULL + MENU FINAL STABLE

set -e
export DEBIAN_FRONTEND=noninteractive

BIN="/usr/local/bin/zivpn-core"
MENU="/usr/local/bin/zivpn"
CONF="/etc/zivpn/config.json"
SERVICE="/etc/systemd/system/zivpn.service"
PORT="5667"

URL="https://github.com/mandiriwe1/zivpn-installer/releases/download/Udp/udp-zivpn-linux-amd64.1"

echo "[1/7] Install dependencies..."
apt-get update -y >/dev/null 2>&1
apt-get install -y wget curl jq openssl iptables ufw iproute2 procps file python3 >/dev/null 2>&1

mkdir -p /etc/zivpn /usr/local/bin

echo "[2/7] Download binary..."
rm -f "$BIN"

for i in 1 2 3 4 5; do
  wget -q --timeout=20 -O "$BIN" "$URL" && break
  sleep 2
done

chmod +x "$BIN"

if ! file "$BIN" | grep -qi "ELF"; then
  echo "❌ Binary invalid"
  exit 1
fi

echo "[3/7] Create config..."
cat > "$CONF" <<EOF
{
  "listen": ":$PORT",
  "cert": "/etc/zivpn/zivpn.crt",
  "key": "/etc/zivpn/zivpn.key",
  "obfs": "zivpn",
  "auth": { "mode": "passwords", "config": [] }
}
EOF

openssl req -x509 -newkey rsa:2048 -nodes \
-keyout /etc/zivpn/zivpn.key \
-out /etc/zivpn/zivpn.crt \
-days 365 -subj "/CN=zivpn" >/dev/null 2>&1

echo "[4/7] Service install..."
cat > "$SERVICE" <<EOF
[Unit]
Description=YHDS ZIVPN
After=network.target

[Service]
ExecStart=$BIN server -c $CONF
Restart=always
RestartSec=2
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable zivpn >/dev/null 2>&1
systemctl restart zivpn

echo "[5/7] Install MENU..."

cat > "$MENU" <<'EOF'
#!/bin/bash

CONF="/etc/zivpn/config.json"
BACKUP="/root/zivpn-backup.json"

BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

get_ip(){ curl -s https://api.ipify.org || echo "0.0.0.0"; }
get_isp(){ curl -s --max-time 2 ipinfo.io/org 2>/dev/null || echo "UNKNOWN"; }
get_ram(){ free -m | awk 'NR==2{printf "%s/%sMB", $3,$2}'; }

status(){
systemctl is-active --quiet zivpn && echo "ONLINE" || echo "OFFLINE"
}

pause(){ read -p "ENTER..."; }

safe(){
mkdir -p /etc/zivpn
[ -f "$CONF" ] || echo '{"auth":{"config":[]}}' > "$CONF"
}

banner(){
clear

echo -e "${BLUE}"
echo "███████╗██╗   ██╗██████╗ ███████╗███╗   ██╗"
echo "██╔════╝╚██╗ ██╔╝██╔══██╗██╔════╝████╗  ██║"
echo "███████╗ ╚████╔╝ ██████╔╝█████╗  ██╔██╗ ██║"
echo "╚════██║  ╚██╔╝  ██╔═══╝ ██╔══╝  ██║╚██╗██║"
echo "███████║   ██║   ██║     ███████╗██║ ╚████║"
echo "╚══════╝   ╚═╝   ╚═╝     ╚══════╝╚═╝  ╚═══╝"
echo -e "${NC}"

echo -e "${BLUE}┌────────────────────────────────────┐${NC}"
echo -e "${BLUE}        YHDS ZIVPN PANEL            ${NC}"
echo -e "${BLUE}────────────────────────────────────${NC}"
echo -e "${BLUE} IP     : $(get_ip)              ${NC}"
echo -e "${BLUE} STATUS : $(status)              ${NC}"
echo -e "${BLUE} ISP    : $(get_isp)             ${NC}"
echo -e "${BLUE} RAM    : $(get_ram)             ${NC}"
echo -e "${BLUE} PORT   : 5667                   ${NC}"
echo -e "${BLUE}└────────────────────────────────────┘${NC}"

echo ""

echo -e "${YELLOW}┌──────────── MENU ────────────┐"
echo -e "│ 1  Create Account            │"
echo -e "│ 2  Renew Account             │"
echo -e "│ 3  Delete Account            │"
echo -e "│ 4  List Accounts             │"
echo -e "│ 5  Backup                    │"
echo -e "│ 6  Restore                   │"
echo -e "│ 7  Restart                   │"
echo -e "│ 8  API Key                   │"
echo -e "│ 9  View API Key              │"
echo -e "│ 10 Speedtest                 │"
echo -e "│ 11 Fix                       │"
echo -e "│ 12 Auto Reboot               │"
echo -e "│ 13 Delete Expired            │"
echo -e "│ 14 Change Domain             │"
echo -e "│ 0  Exit                      │"
echo -e "└──────────────────────────────┘${NC}"
}

create(){
read -p "Password: " p
read -p "Hari aktif: " d
u="user$(date +%s)"
exp=$(date -d "+$d days" +%s)

jq --arg v "$u:$p:$exp" '.auth.config += [$v]' "$CONF" > /tmp/a.json && mv /tmp/a.json "$CONF"
systemctl restart zivpn
echo "✔ CREATED"
pause
}

renew(){
read -p "Password: " p
read -p "Tambah hari: " d
exp=$(date -d "+$d days" +%s)

jq --arg p "$p" --arg e "$exp" '.auth.config |= map(if (split(":")[1]==$p) then (split(":")[0]+":"+$p+":"+$e) else . end)' "$CONF" > /tmp/a.json && mv /tmp/a.json "$CONF"

systemctl restart zivpn
echo "✔ RENEW OK"
pause
}

delete(){
read -p "Password: " p
jq --arg p "$p" '.auth.config |= map(select(split(":")[1] != $p))' "$CONF" > /tmp/a.json && mv /tmp/a.json "$CONF"

systemctl restart zivpn
echo "✔ DELETED"
pause
}

list(){ jq -r '.auth.config[]?' "$CONF"; pause; }

backup(){ cp "$CONF" "$BACKUP"; echo "✔ BACKUP OK"; pause; }
restore(){ cp "$BACKUP" "$CONF"; systemctl restart zivpn; echo "✔ RESTORE OK"; pause; }
restart(){ systemctl restart zivpn; echo "✔ RESTART OK"; pause; }

api(){ echo "$(tr -dc A-Za-z0-9 </dev/urandom | head -c 24)" > /etc/zivpn/api.key; echo "✔ API CREATED"; pause; }
view(){ cat /etc/zivpn/api.key 2>/dev/null || echo "NO KEY"; pause; }

speedtest(){ curl -s https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py | python3; pause; }

fix(){ systemctl restart zivpn; echo "✔ FIX OK"; pause; }

auto(){
grep -q zivpn /etc/crontab || echo "0 */6 * * * root systemctl restart zivpn" >> /etc/crontab
echo "✔ AUTO ON"
pause
}

expired(){
NOW=$(date +%s)
tmp=$(mktemp)

jq -r '.auth.config[]?' "$CONF" | while read l; do
e=$(echo $l|cut -d: -f3)
[ "$e" -gt "$NOW" ] && echo "$l"
done > "$tmp"

jq -R . "$tmp" | jq -s . > /tmp/x
mv /tmp/x "$CONF"

systemctl restart zivpn
echo "✔ CLEANED"
pause
}

change_domain(){
read -p "New Domain: " d
echo "$d" > /etc/zivpn/domain.conf
echo "✔ DOMAIN CHANGED"
pause
}

menu(){
while true; do
safe
banner
read -p "Choose: " c
case $c in
1) create ;;
2) renew ;;
3) delete ;;
4) list ;;
5) backup ;;
6) restore ;;
7) restart ;;
8) api ;;
9) view ;;
10) speedtest ;;
11) fix ;;
12) auto ;;
13) expired ;;
14) change_domain ;;
0) exit ;;
*) echo "Wrong"; sleep 1 ;;
esac
done
}

menu
EOF

chmod +x "$MENU"

echo "[7/7] DONE"
echo "ketik: zivpn"
