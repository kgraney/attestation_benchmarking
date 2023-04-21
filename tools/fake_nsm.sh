#!/bin/bash -x
set -e
device=/dev/nsm

cleanup() {
  rm -f $device
}
trap cleanup EXIT

mkfifo --mode=0666 $device

while true
do
   read data < $device
   echo "$data" > $device
done

