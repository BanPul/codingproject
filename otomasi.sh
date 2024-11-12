#!/bin/bash

# Define variables for Ubuntu setup
VLAN_INTERFACE="eth1.10"
VLAN_ID=10
IP_ADDRESS="192.168.20.1/24"
DHCP_RANGE_START="192.168.20.10"
DHCP_RANGE_END="192.168.20.100"
DNS_SERVER="8.8.8.8"
GATEWAY="192.168.20.1"

echo "Starting network setup..."

# Step 1: Configure Kartolo Repository for Ubuntu 20.04
echo "Configuring kartolo repository..."
echo "deb http://kartolo.sby.datautama.net.id/ubuntu focal main restricted universe multiverse" > /etc/apt/sources.list
echo "deb http://kartolo.sby.datautama.net.id/ubuntu focal-updates main restricted universe multiverse" >> /etc/apt/sources.list
echo "deb http://kartolo.sby.datautama.net.id/ubuntu focal-backports main restricted universe multiverse" >> /etc/apt/sources.list
echo "deb http://kartolo.sby.datautama.net.id/ubuntu focal-security main restricted universe multiverse" >> /etc/apt/sources.list
echo "deb http://kartolo.sby.datautama.net.id/ubuntu focal-proposed main restricted universe multiverse" >> /etc/apt/sources.list
apt update && apt upgrade -y

# Step 2: Install necessary packages
echo "Installing necessary packages..."
apt install -y vlan isc-dhcp-server iptables-persistent

# Step 3: Enable VLAN on the network interface
echo "Setting up VLAN interface $VLAN_INTERFACE..."
modprobe 8021q
ip link add link eth1 name $VLAN_INTERFACE type vlan id $VLAN_ID
ip addr add $IP_ADDRESS dev $VLAN_INTERFACE
ip link set up dev $VLAN_INTERFACE

# Step 4: Configure DHCP server
echo "Configuring DHCP server..."
cat <<EOL > /etc/dhcp/dhcpd.conf
subnet 192.168.20.0 netmask 255.255.255.0 {
    range $DHCP_RANGE_START $DHCP_RANGE_END;
    option routers $GATEWAY;
    option subnet-mask 255.255.255.0;
    option domain-name-servers $DNS_SERVER;
    default-lease-time 600;
    max-lease-time 7200;
}
EOL

# Assign the VLAN interface to DHCP
sed -i 's/INTERFACESv4=""/INTERFACESv4="'$VLAN_INTERFACE'"/' /etc/default/isc-dhcp-server

# Restart DHCP service
echo "Starting DHCP server..."
systemctl restart isc-dhcp-server
systemctl enable isc-dhcp-server

# Step 5: Enable IP forwarding
echo "Enabling IP forwarding..."
sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf

# Step 6: Configure NAT for Internet access
echo "Configuring NAT..."
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
iptables -A FORWARD -i $VLAN_INTERFACE -o eth0 -j ACCEPT
iptables -A FORWARD -i eth0 -o $VLAN_INTERFACE -m state --state RELATED,ESTABLISHED -j ACCEPT

# Save iptables rules
echo "Saving iptables rules..."
netfilter-persistent save

# Step 7: Configure SSH and Telnet Access for Cisco and MikroTik Devices
echo "Configuring remote access..."

# Install SSH server
apt install -y openssh-server

# Allow Telnet (for testing purposes) - Uncomment below lines if Telnet is necessary
# apt install -y telnetd
# systemctl enable inetd
# systemctl start inetd

echo "Remote access configuration completed!"

# Cisco Switch Configuration (To be entered on the Cisco device):
echo "
===== Cisco Switch Configuration =====
enable
configure terminal
vlan 10
name VLAN_10
exit

interface e0/1
switchport mode access
switchport access vlan 10
exit

interface e0/0
switchport mode trunk
exit

line vty 0 4
password cisco123
login
transport input ssh telnet
exit

end
write memory
======================================
"

# MikroTik Router Configuration (To be entered on the MikroTik device):
echo "
===== MikroTik Router Configuration =====
/interface vlan
add interface=ether1 name=vlan10 vlan-id=10

/ip address
add address=192.168.20.2/24 interface=vlan10
add address=192.168.200.1/24 interface=ether2

/ip route
add dst-address=0.0.0.0/0 gateway=192.168.20.1

/ip dhcp-client
add interface=ether1 use-peer-dns=yes use-peer-ntp=yes

/ip firewall nat
add chain=srcnat out-interface=ether1 action=masquerade

/ip service
set telnet address=192.168.20.0/24 port=23
set ssh address=192.168.20.0/24 port=22
=========================================
"

echo "All steps are complete. For Cisco and MikroTik, please enter the above configurations manually."
