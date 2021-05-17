#!/bin/bash
device_id=$1

fail() { echo -e "ERROR: packet: $@" 1>&2; exit 1; }

help_text=`cat << __EOT__
Usage: delete.sh <packet server id>

Delete packet server by id.
__EOT__
`

function packet-cli() {
    "$HOME"/go/bin/packet-cli $@
}

function packet_cli_terminate_device() {
    packet-cli -j device delete -f -i "$device_id"
}

if [ -z "$device_id" ]; then
  fail "$help_text"
fi

packet_cli_terminate_device