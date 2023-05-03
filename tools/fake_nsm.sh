#!/bin/bash -x
set -e
device=/dev/nsm

cleanup() {
  rm -f $device
}
trap cleanup EXIT

mkfifo --mode=0666 $device

exec 3<>$device
#RUST_LOG=debug ./target/release/attestation_benchmarking 0<&3 1>&3
python3 tools/echo.py 0<&3 1>&3
