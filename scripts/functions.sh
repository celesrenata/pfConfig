#!/bin/bash

#!/bin/bash

# Get current dir
cwd=$(pwd)

# Create timestamp for logs
timestamp=$(date '+%Y%m%d-%H%M%S')

# Create log directory
mkdir -p rapid-fog-logs

# Install jq before it is needed!
if [ $(apt list --installed jq 2> /dev/null | wc -l) -eq 1 ]; then
    apt-get install jq -y
fi

# Load configuration values
active_tests=($(jq -c ".general.active_tests[]" config.json | sed 's/[{|}]//g' | tr ',' '\n' | sed 's/"//g'))
prerequisites=($(jq -c ".general.prerequisites[]" config.json | sed 's/[{|}]//g' | tr ',' '\n' | sed 's/"//g'))
log_dir=$(cat config.json | jq -r .general.settings.log_dir)

# Create Build Log Folder
mkdir -p "${log_dir}"

function aptSafe()
{
  appTask=$1
  while ! DEBIAN_FRONTEND=noninteractive apt-get $appTask
  do
    echo "woops, dpkg not ready, backing off"
    while fuser /var/lib/dpkg/lock > /dev/null 2>&1
    do
      sleep .1
      echo -n "."
    done
  done
}

function did-it-work()
{
  if [[ $? -ne 0 ]]; then
    echo "Failed"
    exit 1
fi
}

function run() {
        if $DEBUG; then
                local v=$(exec 2>&1 && set -x && set -- "$@")
                echo "#${v#*--}"
                "$@"
        else
                "$@" >> "${log_dir}"/run-"${timestamp}" 2>&1 &
                local child=$!
                trap -- "" SIGTERM
                (
                    sleep 10m
                    touch .failure
                    kill $child 2> /dev/null
                ) &
                wait $child
                if [ -e ".failure" ]
                then
                    rm .failure
                    return 1
                else
                    return 0
                fi
        fi
}

function ctrl_c() {
	exit 1
}

function install_nordvpn() {
  # Install Prerequisites
  echo -n "Installing Prerequisites ............ "
  apt install jq curl wireguard -y 2>&1 2>&1 "${log_dir}"
  sh <(curl -sSf https://downloads.nordcdn.com/apps/linux/install.sh)
  usermod -aG nordvpn $USER
  newgrp nordvpn # nested shell
  nordvpn login
  nordvpn connect
  nordvpn_data=$(wg showconf nordlynx)
  nordvpn disconnect
  exit # exit nested shell

  # Get NordVPN data
  nordvpn_private_key=$(echo "${nordvpn_data}" | grep "PrivateKey" | awk -F " = " '{ print $2 }')
  nordvpn_public_key=$(echo "${nordvpn_data}" | grep "PublicKey" | awk -F " = " '{ print $2 }')
  nordvpn_endpoint=$(echo "${nordvpn_data}" | grep "Endpoint" | awk -F " = " '{ print $2 }')
  # Sed Farm
  sed -i ../resources/network-config.template.xml "s~NORD_PRIVATE_KEY~${nordvpn_private_key}~g"
  sed -i ../resources/network-config.template.xml "s~NORD_PUBLIC_KEY~${nordvpn_public_key}~g"
  sed -i ../resources/network-config.template.xml "s/NORD_ENDPOINT/${nordvpn_endpoint}/g"

  return
}

function install_surfshark() {
  echo "Sign into surfshark and navigate to this page: https://my.surfshark.com/vpn/manual-setup/router/wireguard"
  echo -n "Gimmie the Private Key: "
  read -r surfshark_private_key
  echo -n "Now the Endpoint Address: "
  read -r surfshark_endpoint
  echo -n "Now the Public Key: "
  read -r surfshark_public_key
  # Sed Farm
  sed -i ../resources/network-config.template.xml "s~SURF_PRIVATE_KEY~${surfshark_private_key}~g"
  sed -i ../resources/network-config.template.xml "s~SURF_PUBLIC_KEY~${surfshark_public_key}~g"
  sed -i ../resources/network-config.template.xml "s/SURF_ENDPOINT/${surfshark_endpoint}/g"

  return
}

function install_mullvad() {
  echo -n "What is your MullVad UserID?: "
  read -r mullvad_userid
  echo -n "What is the public endpoint address?: "
  read -r mullvad_endpoint
  echo -n "What is the Public Key Associated with your endpoint?: "
  read -r mullvad_public_key
  wg genkey | tee /tmp/privkey | wg pubkey > /tmp/pubkey
  curl https://api.mullvad.net/wg/ -d account="${mullvad_userid}" --data-urlencode pubkey=$(cat /tmp/pubkey) | tee /tmp/mullvad-ip
  mullvad_gateway=$(cat /tmp/mullvad-ip | awk -F "/" '{ print $1 }')
  mullvad_private_key=$(cat /tmp/privkey)
  # Sed Farm
  sed -i ../resources/network-config.template.xml "s~MULLVAD_PRIVATE_KEY~${mullvad_private_key}~g"
  sed -i ../resources/network-config.template.xml "s~MULLVAD_PUBLIC_KEY~${mullvad_public_key}~g"
  sed -i ../resources/network-config.template.xml "s/MULLVAD_ENDPOINT/${mullvad_endpoint}/g"
  sed -i ../resources/network-config.template.xml "s/MULLVAD_GATEWAY/${mullvad_gateway}/g"

  return
}