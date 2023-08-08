#!/bin/bash

# This script uses a preconfigured pfSense configuration file. You can use the underlying script to manage your network.
DEBUG=true
source functions.sh
# Run requirements tests
if [[ " ${active_tests[*]} " =~ " sudo " ]]; then
    ./tests.sh sudo
    did-it-work
fi

echo -n "Installing Prerequisites ............ "
apt install jq curl wireguard -y 2>&1 2>&1 "${log_dir}"

echo "I have questions."
echo "I currently support NordVPN, SurfShark, and MullVAd in WireGuard format"
echo -n "Do you want to configure NordVPN? (y/n): "
read -r nordvpn
echo -n "Do you want to configure SurfShark? (y/n): "
read -r surfshark
echo -n "Do you want to configure MullVad? (y/n): "
read -r mullvad

# Get WireGuard configs from user.
case ${nordvpn} in
  [Yy]* ) install_nordvpn;;
  [Nn]* ) config_nordvpn=null;;
esac
case ${surfshark} in
  [Yy]* ) install_surfshark;;
  [Nn]* ) config_surfshark=null;;
esac
case ${mullvad} in
  [Yy]* ) install_mullvad;;
  [Nn]* ) config_mullvad=null;;
esac

cp ../resources/network-config.template.json ../resources/network-config.json
echo "I have more questions!"
echo "Now that we have your wireguard settings, we need to build the config. The process is mostly harmless."
echo -n "Hostname? (wireguard): "
read -r varHostname
varHostname=${varHostname:-wireguard}
sed -i "s/varHOSTNAME/${varHostname}/g" ../resources/network-config.json
echo -n "Domain? (home.apra): "
read -r varDomain
varDomain=${varDomain:-home.apra}
sed -i "s/varDOMAIN/${varDomain}/g" ../resources/network-config.json
echo -n "Firewall IP Address? (192.168.1.1): "
read -r varIpaddress
varIpaddress=${varIpaddress:-192.168.1.1}
sed -i "s/varHOSTIPADDRESS/${varIpaddress}/g" ../resources/network-config.json
echo -n "LAN CIDR? (192.168.1.0/24): "
read -r varLancidr
varLancidr=${varLancidr:-192.168.1.0/24}
sed -i "s~varLANCIDR~${varLancidr}~g" ../resources/network-config.json
echo -n "What username do you want to use for VPN login? (riley): "
read -r varVpnuser
varVpnuser=${varVpnuser:-riley}
sed -i "s/varVPNUSER/${varVpnuser}/g" ../resources/network-config.json
echo "QEMU uses vtnet0 ..."
echo "VMWare uses vtnet0 ..."
echo "Virtualbox uses em0 ..."
echo "Baremetal? you are on your own."
echo -n "What interface would you like to use for WAN? (vtnet0): "
read -r varWaninterface
varWaninterface=${Waninterface:-vtnet0}
sed -i "s/varWANINTERFACE/${varWaninterface}/g" ../resources/network-config.json
echo -n "What interface would you like to use for LAN? (vtnet1): "
read -r varLaninterface
varLaninterface=${varLaninterface:-vtnet1}
sed -i "s/varLANINTERFACE/${varLaninterface}/g" ../resources/network-config.json
echo -n "What is the IP of your tftp server? (192.168.1.252): "
read -r varNextserver
varNextserver=${varNextserver:-192.168.1.252}
sed -i "s/varNEXT_SERVER/${varNextserver}/g" ../resources/network-config.json

# Build the config!
python3 migrate-config.py ../resources/config.template.xml