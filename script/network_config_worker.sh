#!/bin/bash

read -p "MAIN_SERVER_IP: " MAINSERVERIP
read -p "MAIN_SERVER_GATEWAY_ADRESS: " GATEWAYADRESS
read -p "NETMASK: " NETMASK
read -p "BROADCAST: " BROADCASTIP
read -p "NETWORK_INTERFACE: " NETWORK_INTERFACE
read -p "VSWITCH_LAN: " VSWITCH_LAN

echo "
### Hetzner Online GmbH installimage

source /etc/network/interfaces.d/*

auto lo
iface lo inet loopback
iface lo inet6 loopback


iface ${NETWORK_INTERFACE} inet manual


iface ${NETWORK_INTERFACE} inet6 static
  address 2a01:4f8:110:5143::2
  netmask 64
  gateway fe80::1


auto vmbr0
iface vmbr0 inet static
        address  ${MAINSERVERIP}
        netmask  32
        gateway  ${GATEWAYADRESS}
        broadcast  ${BROADCASTIP}
        bridge-ports ${NETWORK_INTERFACE}
        bridge-stp off
        bridge-fd 0
        pointopoint ${GATEWAYADRESS}
#WAN

iface vmbr0 inet6 auto
        post-up echo 2048 > /sys/class/net/vmbr0/bridge/hash_max
        post-up echo 1 > /sys/class/net/vmbr0/bridge/multicast_snooping
        post-up echo 0 > /proc/sys/net/ipv6/conf/vmbr0/accept_ra

  up ip route add -net ${GATEWAYADRESS} netmask 255.255.255.224 gw ${GATEWAYADRESS} vmbr0
  up sysctl -w net.ipv4.ip_forward=1
  up sysctl -w net.ipv4.conf.${NETWORK_INTERFACE}.send_redirects=0
  up sysctl -w net.ipv6.conf.all.forwarding=1

# Virtual switch for DMZ
# (connect your firewall/router KVM instance and private DMZ hosts here)
auto vmbr1
iface vmbr1 inet manual
        bridge_ports ${NETWORK_INTERFACE}.${VSWITCH_LAN}
        bridge_stp off
        bridge_fd 0
#LAN0




" >interfaces

read -p "NUMBER_OF_NODES (e.g. 3 Nodes (only worker nodes) = 1 2 3): " NUMBER_OF_NODES

for node in ${NUMBER_OF_NODES}; do
  read -p "VSWITCH_COROSYNC: " VSWITCH_COROSYNC
  read -p "IP_ADRESS_COROYSYNC (e.g. 10.0.100.11, 10.0.200.11, etc.) " IP_ADRESS_COROYSYNC
  echo "

#vlan between nodes
auto vmbr${VSWITCH_COROSYNC}
iface vmbr${VSWITCH_COROSYNC} inet static
        bridge_ports   ${NETWORK_INTERFACE}.${VSWITCH_COROSYNC}
        bridge_stp      off
        bridge_fd       0
        address         ${IP_ADRESS_COROYSYNC}
        netmask         24
#COROSYNC${node}

" >>interfaces
done

cat interfaces

while true; do
  read -p "Config correct? [yes][no]: " yn
  case $yn in
  [Yy]*)
    echo ""
    break
    ;;
  [Nn]*)
    rm interfaces
    exit
    ;;
  *) echo "Please answer yes or no." ;;
  esac
done

mv /etc/network/interfaces /etc/network/interfaces.old
mv interfaces /etc/network/interfaces
echo "The network can be restarted with the following command:      /etc/init.d/networking restart    "
