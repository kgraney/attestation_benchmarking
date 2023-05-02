#!/bin/bash
# cargo-criterion unfortunately outputs JSON to stdout in one stream, so this
# splits it into individual report files for easier processing.
json_out=all.json
cargo criterion --message-format=json > $json_out
while read -r line
do
  out_dir=$(echo "$line" | jq -r '.["report_directory"]')
  echo $line > "${out_dir}/raw.json"
done < $json_out
