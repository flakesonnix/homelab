#!/usr/bin/env bash
set -euo pipefail

if [[ $# != 2 ]]; then
  printf 'Usage: %s VID PID\n' "$0" >&2
  exit 2
fi

vid=$1
pid=$2

lsusb_device=$(lsusb -d "$vid:$pid")
if [[ -z $lsusb_device ]]; then
  printf 'Device %s:%s not found\n' "$vid" "$pid" >&2
  exit 2
fi

usb_bus=$(printf '%s\n' "$lsusb_device" | awk '{ print $2; }' | cut -c 1-3)
usb_device=$(printf '%s\n' "$lsusb_device" | awk '{ print $4; }' | cut -c 1-3)
usb_devpath=/sys$(udevadm info -q property --property=DEVPATH "/dev/bus/usb/$usb_bus/$usb_device" | awk -F = '{ print $2; }')
usb_location=$(printf '%s\n' "$usb_devpath" | awk -F / '{ print $NF; }')
hub_location=$(printf '%s\n' "$usb_location" | awk -F . '{ print $1; }')
hub_port=$(printf '%s\n' "$usb_location" | awk -F . '{ print $2; }')

uhubctl --force --location "$hub_location" --ports "$hub_port" --action cycle
