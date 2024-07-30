#!/bin/ash

#check if tun device has ip
tun_ip=$(ip -4 addr show tun0 | grep inet | xargs echo -n | cut -d' ' -f2 2>/dev/null)
if [[ $tun_ip =~ ^\\d+\.\\d+\.\\d+\.\\d+\/\\d+$ ]]; then
  exit 0
else
  exit 1
fi
