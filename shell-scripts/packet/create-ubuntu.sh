#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
EDEN_DIR=$SCRIPT_DIR/../../

while true; do
   case "$1" in
     -l*) #shellcheck disable=SC2039
          location="${1/-l/}"
          if [ -z "$location" ]; then
             location="$2"
             shift
          fi
          shift
          ;;
      -c*) #shellcheck disable=SC2039
          server_conf="${1/-c/}"
          if [ -z "$server_conf" ]; then
             server_conf="$2"
             shift
          fi
          shift
          ;;
       -p*) #shellcheck disable=SC2039
          project="${1/-p/}"
          if [ -z "$project" ]; then
             project="$2"
             shift
          fi
          shift
          ;;
       -ip*) #shellcheck disable=SC2039
          public_ip="${1/-ip/}"
          if [ -z "$public_ip" ]; then
             public_ip="$2"
             shift
          fi
          shift
          ;;
       *) break
          ;;
   esac
done

fail() { echo "ERROR: packet: $@" 1>&2; echo "00000000-0000-0000-0000-000000000000"; exit 1; }

help_text=`cat << __EOT__
Usage: create.sh -l <location> -c <server configuration> -p <packet project id> [OPTIONS]

OPTIONS:
  -ip <public ip address> - Setup ip address for ipxe.cfg url.
      By default parsed from <EDEN_DIR>/dist/default-images/eve/tftp/ipxe.efi.cfg

Returns the id of the created packet server to the stdout or 00000000-0000-0000-0000-000000000000 
as server id on create fail.
------------------------------------------------------------------------------------------------------
__EOT__
`

function eden_get_ipxe_cfg_url() {
  if ! [ -f "$EDEN_DIR"/dist/default-images/eve/tftp/ipxe.efi.cfg ]; then
    exit 1
  fi
  set_url_str=$(cat "$EDEN_DIR"/dist/default-images/eve/tftp/ipxe.efi.cfg | grep "set url")
  # Setup public IP
  if ! [ -z "$public_ip" ]; then
    current_ip=$(echo "$set_url_str" | grep -o '[0-9]\+[.][0-9]\+[.][0-9]\+[.][0-9]\+')
    set_url_str=$(echo ${set_url_str/"$current_ip"/"$public_ip"})
  fi
  echo "${set_url_str/"set url "/""}ipxe.efi.cfg"
}

function packet-cli() {
   if [ -e $HOME/go/bin/packet-cli ]; then
     "$HOME"/go/bin/packet-cli $@
   else
      $GOPATH/bin/packet-cli $@
   fi
}

function packet_cli_create_ubuntu() {
  counter_create=${1:-0}
  packet_id=$(packet-cli -j device create -f "$location" \
        -H eden-gh-actions-"$server_conf" \
        -o ubuntu_20_04 \
        -P "$server_conf" --tags="eden,gh,actions" -p "$project" | \
        jq -r '.["id"]?')
  if echo "$packet_id" | grep -q "null" || [ -z "$packet_id" ]; then
    if [ "$counter_create" -gt "10" ]; then
      fail "packet-cli thrown an error while creating"
    fi
    sleep 10
    packet_cli_create_eve $((counter_create + 1))
  else
    echo "$packet_id"
  fi
}

if [ -z "$location" ] || [ -z "$server_conf" ] || [ -z "$project" ]; then
  fail "$help_text"
fi

$SCRIPT_DIR/tools/cli-prepare.sh
packet_cli_create_ubuntu
