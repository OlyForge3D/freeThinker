#!/usr/bin/env bash
set -euo pipefail

if ! command -v nmap >/dev/null 2>&1; then
  echo "[thinker-x400] scan hook skipped: nmap is not installed" >&2
  exit 0
fi

work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

hosts_file="$work_dir/nmap_hosts.txt"
ips_file="$work_dir/open_ips.txt"
out_file="{{PRINTER_HOME}}/mainsail/all/printers.txt"

nmap -p 7125 192.168.2.1/24 -oG "$hosts_file" >/dev/null 2>&1
sed -n '/open/p' "$hosts_file" | sed 's/^.*Host: //g' | sed 's/ (.*$//g' >"$ips_file"

result=""
while IFS= read -r ip; do
  [[ -n "$ip" ]] || continue
  hostname_url="${ip}/all/hostname"
  host_name="$(curl -s "$hostname_url" || true)"
  result+="${host_name},${ip};"
done <"$ips_file"

mkdir -p "$(dirname "$out_file")"
printf '%s\n' "$result" | sed 's/;/\n/g' >"$out_file"
